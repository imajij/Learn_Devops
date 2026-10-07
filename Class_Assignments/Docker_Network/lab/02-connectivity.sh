#!/bin/bash
# Task 1: connectivity checks. Run from Docker_Network/: bash lab/02-connectivity.sh > lab/02-connectivity.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
until docker exec ajij-database mysqladmin -uroot -plabpass ping >/dev/null 2>&1; do sleep 2; done
# MySQL client for the backend test. mariadb-connector-c provides the caching_sha2_password plugin that MySQL 8.4 needs
# (first try without it failed: see lab/02-connectivity-first-try.txt)
docker exec ajij-backend apk add --no-cache mariadb-client mariadb-connector-c >/dev/null 2>&1
echo "### frontend -> backend (both on ajij-frontend-net): works, by container name via Docker's DNS"
r "docker exec ajij-frontend ping -c 2 ajij-backend"
echo "### (the backend runs no web server, so 'Connection refused' still proves the packet reached it)"
r "docker exec ajij-frontend wget -qO- --timeout=3 http://ajij-backend"
echo "### backend -> frontend: HTTP to nginx works"
r "docker exec ajij-backend wget -qO- http://ajij-frontend | grep -o '<title>.*</title>'"
echo "### backend -> database (both on ajij-backend-net): TCP 3306 open, real SQL query works"
r "docker exec ajij-backend nc -zv -w 3 ajij-database 3306"
r "docker exec ajij-backend mariadb -h ajij-database -uroot -plabpass --skip-ssl -e 'SELECT @@hostname AS db_host, VERSION() AS version; SHOW DATABASES LIKE \"school\";'"
echo "### frontend -> database (no shared network): isolated"
r "docker exec ajij-frontend ping -c 2 -W 2 ajij-database"
r "docker exec ajij-frontend ping -c 2 -W 2 172.30.2.3"
r "docker exec ajij-frontend nc -zv -w 3 172.30.2.3 3306"
echo "### the database network is internal (no gateway to the outside world)"
r "docker network inspect -f '{{.Name}} internal={{.Internal}} subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}' ajij-frontend-net ajij-backend-net ajij-database-net"
