#!/usr/bin/env bash
# Declarative + prune: a resource exists because its YAML is in Git; delete the YAML and Argo CD deletes it.
source "$(dirname "$0")/lib.sh"; cd "$REPO"
step 11-prune
c "add a ConfigMap (and fail stuck rollouts after 60 s, used later in the rollback demo)"
cat > app/configmap.yaml <<'YAML'
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-feature-flags
  namespace: gitops-demo
data:
  new_checkout: "true"
YAML
sed -i '' 's/^  replicas: 3$/  replicas: 3\n  progressDeadlineSeconds: 60/' app/deployment.yaml
r "git add -A && git commit -qm 'Add feature-flags ConfigMap; progressDeadlineSeconds 60' && git push -q origin main 2>&1 && git log --oneline -1"
waitsync 120
r "kubectl --context obs -n gitops-demo get configmap web-feature-flags"
c "a ConfigMap created by hand is NOT in Git, so Argo CD does not manage (or prune) it"
r "kubectl --context obs -n gitops-demo create configmap made-by-hand --from-literal=note=not-in-git"
c "now remove the feature-flags YAML from Git"
r "git rm -q app/configmap.yaml && git commit -qm 'Remove feature-flags ConfigMap' && git push -q origin main 2>&1 && git log --oneline -1"
waitsync 120
r "kubectl --context obs -n gitops-demo get configmap"
r "kubectl --context obs -n argocd get events --field-selector involvedObject.name=shop-web --sort-by=.lastTimestamp | grep -iE 'prune|delet|OperationCompleted' | tail -2"
c "the last sync operation, as Argo CD reports it"
r "argocd app get shop-web --show-operation $A | grep -iE 'Operation:|Phase:|ConfigMap'"
r "kubectl --context obs -n gitops-demo delete configmap made-by-hand"
