#!/bin/bash
# Task 1, part 1: clone the instructor's repo (only the multi-stage folder) and copy the app into this assignment.
# Run from DockerFiles_&_Images/: bash lab/01-clone.sh > lab/01-clone.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
A6="$(pwd)"
r "cd ~/devops-lab/docker && rm -rf clone"
r "git clone --depth 1 --filter=blob:none --sparse https://github.com/aryen1101/Learn_DEVOPS.git clone"
r "git -C clone sparse-checkout set 'Docker Concepts/multi-stage-dockerfile'"
r "ls 'clone/Docker Concepts/multi-stage-dockerfile'"
r "cat 'clone/Docker Concepts/multi-stage-dockerfile/Dockerfile'; echo"
r "cat 'clone/Docker Concepts/multi-stage-dockerfile/server.js'; echo"
echo "### copy only the app files (not the instructor's notes/images) into this assignment"
r "mkdir -p \"$A6/multi-stage-app\" && cp 'clone/Docker Concepts/multi-stage-dockerfile/'{Dockerfile,package.json,server.js} \"$A6/multi-stage-app/\""
r "ls \"$A6/multi-stage-app\""
