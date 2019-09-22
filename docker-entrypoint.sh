#!/bin/bash -xe

export PATH=$PATH:/opt/jmeter
GO_APPS=("api-server" "dns-server")
APPS=("admin-server" "${GO_APPS[@]}")

for i in ${APPS[@]}; do
    # if dir does not exist, clone it
    [ -d $i ] || git clone https://gitlab.com/lsoftop/$i
done

# Build go apps
for i in ${GO_APPS[@]}; do
    pushd $i
    go get -v ./...
    go build
    popd
done

/etc/init.d/mysql start
/etc/init.d/redis-server start

mysql -e "CREATE DATABASE lsofadmin"
mysql -e "GRANT ALL ON lsofadmin.* to 'lsofadmin'@'localhost' identified by 'lsofadmin'"
mysql -e "FLUSH PRIVILEGES"

# Start admin-server
pushd admin-server

pip3 install -r requirements.txt

## Run migrations
python3 manage.py migrate

## Start server
python3 manage.py runserver 2&>1 &>admin-server.log &

popd

# Start GO_APPS
for i in ${GO_APPS[@]}; do
    pushd $i
    ./$i > $i.log &
    popd
done

jmeter -n -t loadtest.jmx
