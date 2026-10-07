#!/usr/bin/env bash
# Final cleanup: remove only what this project created (no daemon-wide prune).
source "$(dirname "$0")/common.sh"
r "minikube delete -p final 2>&1 | tail -3"
r "minikube profile list 2>&1 | sed 's/\x1b\[[0-9;]*m//g' | grep -c ' final ' || true"
r "docker rm -f ajij-final-registry ajij-final-localstack 2>&1"
r "docker rmi campusdesk-backend:compose campusdesk-frontend:compose \$(docker images --format '{{.Repository}}:{{.Tag}}' | grep -E '^(localhost:5060/(ajij|mirror)/|campusdesk-(backend|frontend):[0-9a-f]{7}$)') 2>&1 | grep -c -E '^(Untagged|Deleted)'"
r "docker rmi gitea/gitea:1.24.6-rootless localstack/localstack:4.0 postgres:17-alpine nginx:1.31.6-alpine python:3.12.15-slim node:22.23.3-alpine 2>&1 | grep -c -E '^(Untagged|Deleted)'"
r "docker ps -a --format '{{.Names}}' | grep -E 'ajij-final|^final$' || echo 'no project containers left'"
r "docker images --format '{{.Repository}}:{{.Tag}}' | grep -E 'campusdesk|localhost:5060|gitea|localstack' || echo 'no project images left'"
r "docker volume ls --format '{{.Name}}' | grep -E 'campusdesk|^final$' || echo 'no project volumes left'"
r "docker network ls --format '{{.Name}}' | grep -E 'campusdesk|^final$' || echo 'no project networks left'"
r "rm -rf $WORK/artifacts $WORK/tf $WORK/tf-plugin-cache $WORK/venv $WORK/.argo-pw && du -sh $WORK"
