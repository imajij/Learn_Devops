#!/usr/bin/env bash
# Install Argo CD v3.5.4 (non-HA manifest, same install as the course's 07-argocd README but pinned),
# poll Git every 30 s instead of ~3 min, and turn off Dex/notifications (not used here) to save memory.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 07-argocd-install
r "kubectl --context obs create namespace argocd"
r "kubectl --context obs apply -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.4/manifests/install.yaml | tail -4"
r "kubectl --context obs -n argocd patch configmap argocd-cm --type merge -p '{\"data\":{\"timeout.reconciliation\":\"30s\"}}'"
r "kubectl --context obs -n argocd scale deploy argocd-dex-server argocd-notifications-controller --replicas=0"
r "kubectl --context obs -n argocd rollout restart statefulset argocd-application-controller"
r "kubectl --context obs -n argocd rollout status deploy/argocd-server --timeout=300s"
r "kubectl --context obs -n argocd rollout status deploy/argocd-repo-server --timeout=300s"
r "kubectl --context obs -n argocd rollout status statefulset/argocd-application-controller --timeout=300s"
r "kubectl --context obs -n argocd get pods"
