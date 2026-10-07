#!/usr/bin/env bash
# Continuous reconciliation: make manual changes with kubectl (drift) and watch Argo CD undo them.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 10-self-heal
ts "Git says replicas=3 and APP_VERSION=1.1.0. Now change the live objects by hand:"
r "kubectl --context obs -n gitops-demo scale deploy web --replicas=1"
r "kubectl --context obs -n gitops-demo set env deploy/web APP_VERSION=hotfix-by-hand"
for i in 1 2 3 4 5 6; do
  ts "$(kubectl --context obs -n gitops-demo get deploy web -o jsonpath='spec.replicas={.spec.replicas} APP_VERSION={.spec.template.spec.containers[0].env[1].value} ready={.status.readyReplicas}') | argo: $(kubectl --context obs -n argocd get application shop-web -o jsonpath='{.status.sync.status}/{.status.health.status}')"
  sleep 3
done
r "kubectl --context obs -n gitops-demo rollout status deploy/web --timeout=120s"
r "kubectl --context obs -n gitops-demo get deploy web"
r "web"
c "Argo CD's own record of what it did (reason: self-heal / auto-sync)"
r "kubectl --context obs -n argocd get events --field-selector involvedObject.name=shop-web --sort-by=.lastTimestamp | tail -4"
r "kubectl --context obs -n argocd logs statefulset/argocd-application-controller --since=3m | grep shop-web | jq -rR 'fromjson? | select(.msg|test(\"automated sync|OutOfSync|self.?heal\";\"i\")) | \"\\(.time) \\(.msg)\"' | cut -c1-150 | tail -4"
