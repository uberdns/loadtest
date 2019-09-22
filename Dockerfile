FROM golang:1.13

RUN apt update && \
    apt install -y openjdk-11-jre python3 python3-pip default-libmysqlclient-dev default-mysql-server redis

RUN /etc/init.d/mysql start
RUN /etc/init.d/redis-server start

WORKDIR /opt
RUN wget http://apache.osuosl.org//jmeter/binaries/apache-jmeter-5.1.1.tgz && \
    tar xvfz apache-jmeter-5.1.1.tgz && \
    mv apache-jmeter-5.1.1 jmeter

ENV PATH=$PATH:/opt/jmeter/bin

WORKDIR /root

#ENTRYPOINT ["/bin/bash"]
ENTRYPOINT ["/root/docker-entrypoint.sh"]
