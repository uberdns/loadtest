package main

import (
	"flag"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/miekg/dns"
)

var (
	requestTimeMux sync.Mutex
	requestTimes   []time.Duration
	totalRequests  int64
	totalReqMux    sync.Mutex
)

func incrementRequestCounter() {
	totalReqMux.Lock()
	totalRequests++
	totalReqMux.Unlock()
}

func addTimeToRequestTimeTotal(t time.Duration) {
	requestTimeMux.Lock()
	requestTimes = append(requestTimes, t)
	requestTimeMux.Unlock()
}

func performLookup(client dns.Client, request *dns.Msg, done chan bool) (time.Duration, error) {
	_, t, err := client.Exchange(request, "127.0.0.1:53")
	// this blocks the calling function from completing before this one even starts
	done <- true
	return t, err
}

func performThreadLookup(target string, count int64, done chan bool) {
	dnsRequest := new(dns.Msg)
	dnsClient := new(dns.Client)
	if string(target[len(target)-1]) != "." {
		target = fmt.Sprintf("%s.", target)
	}

	dnsRequest.SetQuestion(target, dns.TypeA)
	dnsRequest.SetEdns0(4096, true)

	for i := int64(0); i <= count; i++ {
		localDone := make(chan bool, 1)
		t, err := performLookup(*dnsClient, dnsRequest, localDone)

		if err != nil {
			log.Fatal(err)
		}
		addTimeToRequestTimeTotal(t)
		incrementRequestCounter()
		// execute all of the above and only exit if localDone is set to true
		<-localDone
	}

	done <- true
}

func main() {
	var (
		target           string
		countMax         int64
		threadMax        int
		avgRequestTime   time.Duration
		totalRequestTime time.Duration
	)

	flag.StringVar(&target, "target", "test.lsof.top", "Intended query record for DNS load test")
	flag.Int64Var(&countMax, "count", 100, "Total requests to make per thread")
	flag.IntVar(&threadMax, "threads", 5, "Number of threads to run concurrently")

	flag.Parse()
	done := make(chan bool, 1)
	for i := 0; i <= threadMax; i++ {
		go performThreadLookup(target, countMax, done)
	}
	<-done

	for _, i := range requestTimes {
		totalRequestTime = totalRequestTime + i
	}

	if totalRequestTime.Nanoseconds() != 0 {
		avgRequestTime = time.Duration(totalRequestTime.Nanoseconds() / totalRequests)

		fmt.Println("Total Requests: ", totalRequests)
		fmt.Println("Attempted Requests: ", (countMax * int64(threadMax)))
		fmt.Println("Threads: ", threadMax)
		fmt.Println("Avg request time: ", avgRequestTime)
	}

}
