#!/usr/bin/env bash
# Step 10b: push the project to the in-cluster Git server and let Argo CD take over the release.
# Gitea is reached with: kubectl -n gitops port-forward svc/gitea 3030:3000. GITEA_PW = local demo password (env only).
source "$(dirname "$0")/common.sh"
note "create the repository through the Gitea API"
r "curl -s -u ajij:\"\$GITEA_PW\" -X POST localhost:3030/api/v1/user/repos -H 'Content-Type: application/json' -d '{\"name\":\"campusdesk\",\"private\":false,\"default_branch\":\"main\"}' | jq -c '{full_name, private, clone_url}'"
bash "$LAB/sync-workspace.sh"
cd "$WORK/ws"
r "git add -A && git commit -q -m 'gitops: Argo CD application, values-gitops.yaml, troubleshooting files, terraform, monitoring' && git log --oneline --format='%h %an  %s'"
r "git remote add gitea http://localhost:3030/ajij/campusdesk.git 2>/dev/null; git -c credential.helper= push -q http://ajij:\$GITEA_PW@localhost:3030/ajij/campusdesk.git main 2>&1 | grep -v '^remote:' ; git ls-remote http://localhost:3030/ajij/campusdesk.git main"
note "hand over: remove the Helm-managed release (the PVC is kept by its helm.sh/resource-policy: keep annotation) ..."
r "helm --kube-context final uninstall campusdesk -n campusdesk --wait 2>&1 | tail -2"
r "$K -n campusdesk get pvc"
note "... and let Argo CD create everything from Git"
r "$K apply -f $APP/gitops/argocd-application.yaml"
for i in $(seq 30); do
  s=$($K -n argocd get application campusdesk -o jsonpath='{.status.sync.status}/{.status.health.status}')
  [ "$s" = "Synced/Healthy" ] && break; sleep 10
done
r "$K -n argocd get application campusdesk -o custom-columns=APP:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision"
r "$K -n campusdesk get deploy,svc,ingress,hpa,pvc,servicemonitor"
r "curl -s http://campusdesk.localhost:8088/api/tickets/stats; echo"
