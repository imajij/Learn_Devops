#!/usr/bin/env bash
# Step 3: local "cloud": minikube profile `final` + a private registry container.
# Already executed before this transcript (kept here so the run is repeatable):
#   minikube start -p final --driver=docker --cpus=3 --memory=4096 --addons=ingress --addons=metrics-server
#   docker run -d --name ajij-final-registry --restart unless-stopped -p 5060:5000 registry:2
#   docker network connect final ajij-final-registry
source "$(dirname "$0")/common.sh"
r "minikube -p final status"
r "$K get nodes -o wide"
r "minikube -p final addons list -o json | jq -r 'to_entries[] | select(.value.Status==\"enabled\") | .key'"
r "docker ps --filter name=ajij-final-registry --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'"
note "make localhost:5060 inside the minikube node resolve to the registry container (containerd mirror)"
r "minikube -p final ssh -- 'sudo mkdir -p /etc/containerd/certs.d/localhost:5060 && printf \"[host.\\\"http://ajij-final-registry:5000\\\"]\n  capabilities = [\\\"pull\\\", \\\"resolve\\\"]\n\" | sudo tee /etc/containerd/certs.d/localhost:5060/hosts.toml'"
r "curl -s localhost:5060/v2/_catalog; echo"
