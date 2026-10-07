#!/usr/bin/env bash
# Step 10: in-cluster Git server + Argo CD, hand the release over from Helm to Argo CD.
source "$(dirname "$0")/common.sh"; cd "$APP"
note "Git server (Gitea) inside the cluster"
r "$K apply -f gitops/git-server.yaml"
r "$K -n gitops rollout status deploy/gitea --timeout=180s"
r "$K -n gitops exec deploy/gitea -- gitea admin user create --username ajij --email ajij@campusdesk.local --password \"\$GITEA_PW\" --admin --must-change-password=false 2>&1 | tail -1"
note "Argo CD v3.5.4 (dex / notifications / applicationset scaled to 0)"
r "CTX=final gitops/argocd-light.sh 2>&1 | tail -4"
r "$K -n argocd rollout status deploy/argocd-server --timeout=300s && $K -n argocd rollout status deploy/argocd-repo-server --timeout=300s"
r "$K -n argocd get pods"
