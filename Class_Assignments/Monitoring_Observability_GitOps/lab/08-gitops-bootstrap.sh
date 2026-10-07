#!/usr/bin/env bash
# Bootstrap: push the desired state to the in-cluster git server, then register it with Argo CD.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 08a-git-server
c "the Git remote is a pod inside the cluster (lighttpd + git-http-backend), not GitHub"
r "kubectl --context obs -n git get deploy,pod,svc,pvc"
r "kubectl --context obs -n git logs deploy/git-server | head -3"
cd "$REPO"
c "first commit of the desired state, authored as Ajij Uttam"
r "git status --short"
r "git add . && git commit -q -m 'Initial desired state: web v1.0.0 with 2 replicas' && git log --oneline"
r "git remote add origin http://localhost:23001/shop-gitops.git   # kubectl port-forward svc/git-server 23001:3000"
r "git push -u origin main 2>&1"
r "kubectl --context obs -n git exec deploy/git-server -- git -C /srv/git/shop-gitops.git log --format='%h %an %s'"
step 08b-argocd-app
cd "$ROOT"
r "argocd login localhost:28080 --username admin --password \"\$(kubectl --context obs -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)\" --insecure --grpc-web"
r "argocd repo add http://git-server.git.svc:3000/shop-gitops.git --grpc-web"
r "argocd repo list --grpc-web"
r "kubectl --context obs apply -f manifests/gitops/application.yaml"
r "argocd app wait shop-web --sync --health --timeout 180 --grpc-web | tail -8"
r "argocd app get shop-web --grpc-web | head -16"
r "kubectl --context obs -n gitops-demo get deploy,pods,svc"
r "web"
