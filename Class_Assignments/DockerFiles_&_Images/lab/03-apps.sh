#!/bin/bash
# Task 3: build each app twice (multi-stage Dockerfile and single-stage Dockerfile.single), run the multi-stage one.
# Run from DockerFiles_&_Images/: bash lab/03-apps.sh   (writes lab/03-<app>.txt and lab/04-sizes.txt)
r(){ echo "\$ $*"; eval "$@" 2>&1; }
for a in node-app:8111:3000 python-app:8112:5000 java-app:8113:8080; do
  IFS=: read app hp cp <<< "$a"
  {
    r "docker build -t ajij-ms-$app:multi ./apps/$app"
    r "docker run -d --name ajij-ms-$app -p $hp:$cp ajij-ms-$app:multi"
    sleep 4
    r "docker ps --filter name=ajij-ms-$app --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
    r "curl -s http://localhost:$hp"; echo
  } > lab/03-$app.txt
  docker build -t ajij-ms-$app:single -f apps/$app/Dockerfile.single ./apps/$app > lab/03-$app-single-build.txt 2>&1
done
{
  r "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E 'REPOSITORY|ajij-ms-|ajij-multistage'"
  r "docker ps --filter name=ajij-m --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'"
} > lab/04-sizes.txt
# Same comparison for the instructor's app (multi-stage-app/Dockerfile vs multi-stage-app/Dockerfile.single)
docker build -t ajij-multistage-webapp:single -f multi-stage-app/Dockerfile.single ./multi-stage-app > lab/03-multistage-app-single-build.txt 2>&1
{
  r "docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E 'REPOSITORY|ajij-ms-|ajij-multistage'"
  r "docker ps --filter name=ajij-m --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'"
} > lab/04-sizes.txt
