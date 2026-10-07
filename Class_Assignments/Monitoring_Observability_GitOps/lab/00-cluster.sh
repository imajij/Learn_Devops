#!/usr/bin/env bash
# Cluster setup. The first start failed (see 00-cluster-first-attempt.txt); the fix was raising the
# Colima VM inotify instance limit, then starting again.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 00-cluster
r "colima ssh -- sysctl fs.inotify.max_user_instances"
r "minikube -p obs status"
r "kubectl --context obs get nodes -o wide"
r "kubectl --context obs version | grep -E \"Client|Server\""
r "helm version --short"
r "kubectl --context obs top nodes"
