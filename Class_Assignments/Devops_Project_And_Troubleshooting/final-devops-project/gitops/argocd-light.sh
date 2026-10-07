#!/usr/bin/env bash
# Install Argo CD (pinned to the CLI version) and switch off the parts this lab does not use,
# to save memory on the 4 GB minikube node.
set -euo pipefail
CTX=${CTX:-final}
kubectl --context "$CTX" create namespace argocd --dry-run=client -o yaml | kubectl --context "$CTX" apply -f -
kubectl --context "$CTX" apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.4/manifests/install.yaml
kubectl --context "$CTX" -n argocd scale deploy argocd-dex-server argocd-notifications-controller argocd-applicationset-controller --replicas=0
