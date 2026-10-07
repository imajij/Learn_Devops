#!/bin/bash
# Task 3 (part 2): edit the file ON THE MAC, then check nginx serves the new content with no restart.
# Run from Docker_Network/: bash lab/04b-bind-mount.sh > lab/04b-bind-mount.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
r "cat > bind-mount-site/index.html <<'HTML'
<h1>Hello students</h1>
<p>This line was added on the Mac while the container kept running.</p>
HTML"
r "curl -s http://localhost:8121"
r "docker exec ajij-nginx-bind cat /usr/share/nginx/html/index.html"
echo "### same start time and RestartCount=0: the container was never restarted"
r "docker inspect -f 'StartedAt={{.State.StartedAt}} RestartCount={{.RestartCount}}' ajij-nginx-bind"
r "docker ps --filter name=ajij-nginx-bind --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
