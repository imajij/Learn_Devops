#!/usr/bin/env bash
# Run .github/workflows/ci-cd.yml locally with act (Docker-based GitHub Actions runner).
#   --network host        : job containers share the Colima VM network, so they reach
#                           the registry (localhost:5060) and the minikube API (192.168.49.2:8443)
#   KUBE_CONFIG secret     : generated at run time for the throw-away minikube cluster, never stored
# usage: lab/act-run.sh [extra act args]
source "$(dirname "$0")/common.sh"
cd "$WORK/ws"
KCFG=$(kubectl config view --context final --minify --flatten \
       | sed -E "s#server: https://127.0.0.1:[0-9]+#server: https://$(minikube -p final ip):8443#" | base64)
act push \
  -W .github/workflows/ci-cd.yml \
  -P ubuntu-latest=catthehacker/ubuntu:act-latest --pull=false \
  --container-daemon-socket /var/run/docker.sock \
  --network host \
  --artifact-server-path "$WORK/artifacts" \
  --var REGISTRY=localhost:5060 --var IMAGE_NAMESPACE=ajij \
  -s KUBE_CONFIG="$KCFG" "$@"
