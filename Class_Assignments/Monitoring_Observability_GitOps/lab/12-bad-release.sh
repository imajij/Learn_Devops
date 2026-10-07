#!/usr/bin/env bash
# A bad release goes out through Git (image tag that does not exist).
source "$(dirname "$0")/lib.sh"; cd "$REPO"
step 12a-bad-release
sed -i '' 's#image: shop-app:1.0#image: shop-app:2.0#; s/value: "1.1.0"/value: "2.0.0"/' app/deployment.yaml
r "git diff --stat && git diff | grep -E '^[-+] '"
r "git commit -qam 'Release web v2.0.0' && git push -q origin main 2>&1 && git log --oneline -1"
waithealth Degraded 240
r "kubectl --context obs -n gitops-demo get pods"
r "argocd app get shop-web $A | sed -n '11,13p'"
r "kubectl --context obs -n gitops-demo get deploy web -o jsonpath='{.status.conditions[?(@.type==\"Progressing\")].message}'; echo"
r "web"
