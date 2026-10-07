#!/bin/bash
# Task 1, part 2: show my edits, build the instructor's multi-stage Dockerfile, run it on port 8080, verify.
# Run from DockerFiles_&_Images/: bash lab/02-build-run.sh > lab/02-build-run.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
CLONE=~/devops-lab/docker/clone/"Docker Concepts/multi-stage-dockerfile"
echo "### my only changes to the instructor's files: the message and the port"
r "diff \"\$CLONE/server.js\" multi-stage-app/server.js"
r "diff \"\$CLONE/Dockerfile\" multi-stage-app/Dockerfile"
r "docker build -t ajij-multistage-webapp ./multi-stage-app"
r "docker run -d -p 8080:8080 --name ajij-multistage-app ajij-multistage-webapp:latest"
sleep 3
r "docker ps --filter name=ajij-multistage-app"
r "curl -s http://localhost:8080"; echo
r "docker logs ajij-multistage-app"
