#!/bin/bash
# Task 4: single-node overlay network demo with Docker Swarm, then leave the swarm again.
# Run from Docker_Network/: bash lab/05-overlay.sh > lab/05-overlay.txt
r(){ echo "\$ $*"; eval "$@" 2>&1; }
echo "### safety check: swarm is off, and other people's containers (kind/minikube nodes) are running"
r "docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'"
r "docker ps --filter name=k8s- --format '{{.Names}}: {{.Status}}'"
echo "### 1. turn this daemon into a one-node swarm (overlay networks need the swarm control plane)"
r "docker swarm init --advertise-addr 192.168.5.1 | head -2"
r "docker node ls"
echo "### 2. create an attachable overlay network"
r "docker network create -d overlay --attachable --subnet 10.20.0.0/24 ajij-overlay"
r "docker network ls --filter driver=overlay"
echo "### 3. a 2-replica service on the overlay network, published through the swarm routing mesh"
r "docker service create --quiet --name ajij-web --replicas 2 --network ajij-overlay -p 8131:80 nginx:alpine"
sleep 15
r "docker service ls --filter name=ajij-web"
r "docker service ps ajij-web --format 'table {{.Name}}\t{{.Node}}\t{{.CurrentState}}'"
echo "### 4. a plain container joins the same overlay and finds the service by name"
r "docker run --rm --name ajij-overlay-client --network ajij-overlay alpine:3.22 sh -c 'nslookup ajij-web | tail -3; nslookup tasks.ajij-web | grep Address | tail -2; wget -qO- http://ajij-web | grep -o \"<title>.*</title>\"'"
r "docker network inspect -f 'driver={{.Driver}} scope={{.Scope}} subnet={{range .IPAM.Config}}{{.Subnet}}{{end}} vxlan-id={{index .Options \"com.docker.network.driver.overlay.vxlanid_list\"}}' ajij-overlay"
echo "### 5. routing mesh: the published port answers on the node's IP (the Colima VM, 192.168.5.1)"
r "colima ssh -- curl -s -m 5 http://192.168.5.1:8131 | grep -o '<title>.*</title>'"
echo "### ...but not on 127.0.0.1: the ingress DNAT rule sends it to a bridge IP, which the kernel drops for loopback sources"
r "colima ssh -- curl -s -m 5 -o /dev/null -w 'localhost:8131 -> HTTP %{http_code}\\n' http://localhost:8131"
r "colima ssh -- sudo iptables -t nat -S DOCKER-INGRESS"
echo "### no process listens on 8131 (it is pure iptables/IPVS), so Colima has nothing to forward to the Mac"
r "curl -s -m 5 http://localhost:8131 || echo 'macOS: not reachable (curl exit '\$?')'"
echo "### 6. clean up and leave the swarm so the shared daemon is back to normal"
r "docker service rm ajij-web"
sleep 5
r "docker network rm ajij-overlay"
r "docker swarm leave --force"
sleep 2
r "docker network rm docker_gwbridge"
r "docker info --format 'Swarm: {{.Swarm.LocalNodeState}}'"
r "docker network ls --filter driver=overlay"
r "docker ps --filter name=k8s- --format '{{.Names}}: {{.Status}}'"
