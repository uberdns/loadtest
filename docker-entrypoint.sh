#!/bin/bash -xe

export PATH=$PATH:/opt/jmeter/bin
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

## Make migrations
python3 manage.py makemigrations
python3 manage.py makemigrations dns

## Run migrations
python3 manage.py migrate

## Start server
python3 manage.py runserver 2>&1 1>admin-server.log &

cat <<EOF > create_user.py
# this must happen before we try to import objects
import django
django.setup()

from django.contrib.auth.models import User
user = User.objects.create_user('loadtest', password='loadtest')
user.is_superuser = False
user.is_staff = False
user.save()

from lsofadmin.dns.models import Domain
domain = Domain.objects.create_domain("lsof.top")
EOF

# https://stackoverflow.com/questions/26082128/improperlyconfigured-you-must-either-define-the-environment-variable-django-set
DJANGO_SETTINGS_MODULE=lsofadmin.settings python3 create_user.py
if [ ! $? -eq 0 ]; then
    exit 1
fi

# Create the API key we use in the loadtest requests
API_KEY="abc123"
CURDATE=$(date "+%Y-%m-%d %T.%N")
SQL_QUERY="INSERT INTO authtoken_token (\`key\`, created, user_id) VALUES ('${API_KEY}', '${CURDATE}', 1)"
mysql -e "${SQL_QUERY}" lsofadmin

popd

# Start GO_APPS
for i in ${GO_APPS[@]}; do
    pushd $i
    ./$i > $i.log 2>&1 &
    popd
done

# pprof on golang services running in background
while ! nc -z localhost 6060; do
    sleep 0.1
done
go tool pprof --svg localhost:6060/debug/pprof/profile?duration=180 > dns-server.svg &

while ! nc -z localhost 6061; do
    sleep 0.1
done
go tool pprof --svg localhost:6061/debug/pprof/profile?duration=180 > api-server.svg &
