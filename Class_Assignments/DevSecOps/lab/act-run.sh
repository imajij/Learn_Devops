#!/usr/bin/env bash
# Runs .github/workflows/devsecops.yml locally with `act`.
# usage: lab/act-run.sh <event> <event.json> [extra act args]
# Prereqs: local registry `ajij-registry` (localhost:5050) and kind cluster `ajij-cicd`
#          (see lab/kind-config.yaml + lab/setup-cluster-registry.sh).
# REGISTRY_* and APP_API_TOKEN are FAKE demo values. KUBE_CONFIG is generated at run time
# for the throwaway local kind cluster and is never written to the repo.
set -uo pipefail
EVENT=$1; EVENTFILE=$2; shift 2
cd "$(dirname "$0")/.."
act "$EVENT" -e "$EVENTFILE" \
  -W .github/workflows/devsecops.yml \
  -P ubuntu-latest=catthehacker/ubuntu:act-latest --pull=false --action-offline-mode \
  --container-daemon-socket /var/run/docker.sock \
  --network host \
  --artifact-server-path "$HOME/devops-lab/cicd/artifacts16" \
  --var REGISTRY=localhost:5050 --var IMAGE_NAMESPACE=ajij \
  -s REGISTRY_USERNAME=ajij-demo \
  -s REGISTRY_PASSWORD=fake-demo-pass-123 \
  -s APP_API_TOKEN=fake-api-token-for-homework \
  -s KUBE_CONFIG="$(kind get kubeconfig --name ajij-cicd | base64)" "$@"
