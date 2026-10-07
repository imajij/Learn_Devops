#!/usr/bin/env bash
# One-time local setup: point the kind node at the local registry container.
#   image name used everywhere : localhost:5050/ajij/devsecops-notes:<sha>
#   inside the kind node        : localhost:5050 is mirrored to http://ajij-registry:5000
set -euo pipefail
docker network connect kind ajij-registry 2>/dev/null || true
for node in $(kind get nodes --name ajij-cicd); do
  docker exec "$node" mkdir -p /etc/containerd/certs.d/localhost:5050
  printf '[host."http://ajij-registry:5000"]\n  capabilities = ["pull", "resolve"]\n' |
    docker exec -i "$node" tee /etc/containerd/certs.d/localhost:5050/hosts.toml
done
