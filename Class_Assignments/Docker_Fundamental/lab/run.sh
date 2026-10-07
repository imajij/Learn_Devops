#!/bin/bash
# Builds and runs the six Hello World apps. Run from Docker_Fundamental/: bash lab/run.sh
# The transcript for each app goes to lab/<app>.txt.
cd "$(dirname "$0")/.."
r(){ echo "\$ $*"; eval "$@" 2>&1; }
# folder  image-name  host-port  container-port
apps="nodejs-app:ajij-nodejs-app:8101:3000 python-app:ajij-python-app:8102:5000 java-app:ajij-java-app:8103:8080
Apache-app:ajij-apache-app:8104:80 React-app:ajij-react-app:8105:80 nginx-app:ajij-nginx-app:8106:80"
for a in $apps; do
  IFS=: read dir img hp cp <<< "$a"
  {
    r "docker build -t $img ./$dir"
    r "docker run -d --name $img -p $hp:$cp $img"
    sleep 4
    r "docker ps --filter name=^$img\$ --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
    r "curl -s http://localhost:$hp | grep -o '<h1>.*</h1>'"
    r "docker logs $img"
  } > lab/$dir.txt
done
{
  r "docker ps --filter name=-app --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
  r "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E 'REPOSITORY|ajij-.*-app'"
  r "curl -s http://localhost:8105 | grep -o '<div id=\"root\"></div>'"
} > lab/all-running.txt
