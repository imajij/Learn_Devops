#!/bin/bash
# Task 3 (part 1): folder on the Mac + index.html, bind-mounted into nginx.
# Run from Docker_Network/: bash lab/04a-bind-mount.sh > lab/04a-bind-mount.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
r "mkdir -p bind-mount-site"
r "echo '<h1>Hello students</h1>' > bind-mount-site/index.html"
r "cat bind-mount-site/index.html"
r "docker run -d --name ajij-nginx-bind -p 8121:80 -v \"\$PWD/bind-mount-site\":/usr/share/nginx/html:ro nginx:alpine"
sleep 2
r "docker inspect -f '{{range .Mounts}}{{.Type}}: {{.Source}} -> {{.Destination}} (rw={{.RW}}){{end}}' ajij-nginx-bind"
r "curl -s http://localhost:8121"
r "docker inspect -f 'StartedAt={{.State.StartedAt}} RestartCount={{.RestartCount}}' ajij-nginx-bind"
