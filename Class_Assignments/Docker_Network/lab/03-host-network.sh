#!/bin/bash
# Task 2: Apache2 (official httpd image) on the HOST network, reached on port 80.
# Run from Docker_Network/: bash lab/03-host-network.sh > lab/03-host-network.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
echo "### with Colima the Docker 'host' is the Linux VM, so check port 80 is free inside the VM first"
r "colima ssh -- sudo ss -tlnp 'sport = :80'"
r "docker pull httpd:2.4"
r "docker run -d --name ajij-apache-host --network host httpd:2.4"
sleep 3
r "docker ps --filter name=ajij-apache-host --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Networks}}\t{{.Ports}}'"
r "docker inspect -f 'NetworkMode={{.HostConfig.NetworkMode}}' ajij-apache-host"
echo "### no -p mapping and no container IP: httpd binds port 80 directly in the VM's network namespace"
r "colima ssh -- sudo ss -tlnp 'sport = :80'"
r "colima ssh -- curl -s http://localhost:80"
echo "### from macOS (Colima/Lima forwards ports that listen in the VM to the Mac's localhost)"
r "curl -s -m 5 http://localhost:80"
