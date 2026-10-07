#!/usr/bin/env bash
# Rollback the GitOps way: git revert (a new commit that undoes the bad one), push, let Argo CD sync.
source "$(dirname "$0")/lib.sh"; cd "$REPO"
step 12b-rollback
r "git revert --no-edit HEAD && git push -q origin main 2>&1"
r "git log --oneline"
waitsync 180
r "kubectl --context obs -n gitops-demo rollout status deploy/web --timeout=120s"
r "kubectl --context obs -n gitops-demo get pods"
r "web"
r "argocd app history shop-web $A"
r "kubectl --context obs -n git exec deploy/git-server -- git -C /srv/git/shop-gitops.git log --format='%h %an  %s'"
