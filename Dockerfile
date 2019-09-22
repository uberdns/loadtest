FROM golang:1.13

RUN apt update && \
    apt install -y jmeter python3 python3-pip default-libmysqlclient-dev default-mysql-server redis

RUN /etc/init.d/mysql start
RUN /etc/init.d/redis-server start

WORKDIR /root

ENTRYPOINT ["/bin/bash"]
