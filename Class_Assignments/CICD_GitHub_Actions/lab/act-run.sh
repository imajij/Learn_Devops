#!/usr/bin/env bash
# Runs .github/workflows/ci-cd.yml locally with `act` (no GitHub needed).
# usage: lab/act-run.sh <event> <event.json> [extra act args]
#   lab/act-run.sh push         lab/events/push-main.json
#   lab/act-run.sh pull_request lab/events/pull-request.json
# Prereq: local registry `ajij-registry` (registry:2 + htpasswd) on localhost:5050.
# All secret values below are FAKE demo values for a throwaway local registry.
set -uo pipefail
EVENT=$1; EVENTFILE=$2; shift 2
cd "$(dirname "$0")/.."
act "$EVENT" -e "$EVENTFILE" \
  -W .github/workflows/ci-cd.yml \
  -P ubuntu-latest=catthehacker/ubuntu:act-latest --pull=false --action-offline-mode \
  --container-daemon-socket /var/run/docker.sock \
  --network host \
  --artifact-server-path "$HOME/devops-lab/cicd/artifacts15" \
  --var REGISTRY=localhost:5050 --var IMAGE_NAMESPACE=ajij \
  -s REGISTRY_USERNAME=ajij-demo \
  -s REGISTRY_PASSWORD=fake-demo-pass-123 \
  -s DEPLOY_TOKEN=fake-deploy-token-for-homework-0000 "$@"
