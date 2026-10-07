#!/usr/bin/env bash
# GitOps workflow: change YAML -> commit -> push -> Argo CD notices -> rollout. No kubectl apply.
source "$(dirname "$0")/lib.sh"; cd "$REPO"
step 09-gitops-workflow
ts "before: what is running"
r "kubectl --context obs -n gitops-demo get deploy web -o wide"
c "edit the desired state: 3 replicas and app version 1.1.0"
sed -i '' 's/replicas: 2/replicas: 3/; s/value: "1.0.0"/value: "1.1.0"/' app/deployment.yaml
r "git diff"
r "git commit -qam 'Release web v1.1.0 and scale to 3 replicas' && git push -q origin main 2>&1 && git log --oneline -1"
ts "pushed - now waiting for Argo CD (polls every 30 s); no kubectl apply is run"
waitsync 180
r "kubectl --context obs -n gitops-demo rollout status deploy/web --timeout=120s"
r "kubectl --context obs -n gitops-demo get deploy web -o wide"
r "kubectl --context obs -n gitops-demo get pods"
r "web"
r "argocd app history shop-web $A"
