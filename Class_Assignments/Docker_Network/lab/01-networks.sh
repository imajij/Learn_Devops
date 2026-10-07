#!/bin/bash
# Task 1: three containers on three user-defined bridge networks; the backend is on two of them.
# Run from Docker_Network/: bash lab/01-networks.sh > lab/01-networks.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
echo "### 1. three user-defined bridge networks (the database one is --internal: no route to the internet)"
r "docker network create --subnet 172.30.1.0/24 ajij-frontend-net"
r "docker network create --subnet 172.30.2.0/24 ajij-backend-net"
r "docker network create --subnet 172.30.3.0/24 --internal ajij-database-net"
echo "### 2. three containers (lab-only DB password, not a real secret)"
r "docker run -d --name ajij-frontend --network ajij-frontend-net nginx:alpine"
r "docker run -d --name ajij-backend --network ajij-frontend-net alpine:3.22 sleep infinity"
r "docker network connect ajij-backend-net ajij-backend"
r "docker run -d --name ajij-database --network ajij-backend-net -e MYSQL_ROOT_PASSWORD=labpass -e MYSQL_DATABASE=school mysql:8.4"
r "docker network connect ajij-database-net ajij-database"
echo "### 3. who is on which network"
r "for n in ajij-frontend-net ajij-backend-net ajij-database-net; do echo \"\$n: \$(docker network inspect -f '{{range .Containers}}{{.Name}}({{.IPv4Address}}) {{end}}' \$n)\"; done"
r "docker inspect -f '{{.Name}} -> {{range \$k, \$v := .NetworkSettings.Networks}}{{\$k}}={{\$v.IPAddress}} {{end}}' ajij-frontend ajij-backend ajij-database"
r "docker ps --filter name=ajij-frontend --filter name=ajij-backend --filter name=ajij-database --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Networks}}'"
