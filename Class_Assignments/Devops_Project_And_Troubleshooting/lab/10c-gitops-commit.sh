#!/usr/bin/env bash
# Step 10c: a change made ONLY through Git reaches the cluster (Argo CD auto-sync), and selfHeal undoes drift.
source "$(dirname "$0")/common.sh"
r "curl -s http://campusdesk.localhost:8088/api/info | jq -r .banner"
note "edit values-gitops.yaml in the repo (no kubectl, no helm)"
cat >> "$APP/helm/campusdesk/values-gitops.yaml" <<'YAML'
  SUPPORT_BANNER: "Exam week (12-16 Oct): Wi-Fi and lab PC tickets are handled first. Helpdesk desk open 8am-8pm."
YAML
python3 - "$APP/helm/campusdesk/values-gitops.yaml" <<'PY'
import sys; p=sys.argv[1]; s=open(p).read()
banner=[l for l in s.splitlines() if "SUPPORT_BANNER" in l][0]
s=s.replace("\n"+banner,"").replace('  APP_VERSION: "1.0.0-9e8f63a"\n','  APP_VERSION: "1.0.0-9e8f63a"\n'+banner+"\n")
open(p,"w").write(s)
PY
bash "$LAB/sync-workspace.sh"; cd "$WORK/ws"
r "git diff --stat && git diff helm/campusdesk/values-gitops.yaml | tail -4"
r "git commit -qam 'config: exam-week support banner' && git log -1 --format='%h %an <%ae>  %s'"
r "git -c credential.helper= push -q http://ajij:\$GITEA_PW@localhost:3030/ajij/campusdesk.git main 2>&1 | grep -v '^remote:'; date -u +'pushed at %H:%M:%S UTC'"
note "wait for Argo CD to notice the commit on its own (default polling interval ~3 min)"
NEW=$(git rev-parse HEAD)
for i in $(seq 40); do
  rev=$($K -n argocd get application campusdesk -o jsonpath='{.status.sync.revision}')
  [ "$rev" = "$NEW" ] && break; sleep 10
done
r "date -u +'synced seen at %H:%M:%S UTC'; $K -n argocd get application campusdesk -o custom-columns=SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision"
r "$K -n argocd get application campusdesk -o jsonpath='{range .status.history[*]}{.id}  {.revision}  {.deployedAt}{\"\\n\"}{end}'"
r "$K -n campusdesk rollout status deploy/campusdesk-backend --timeout=180s"
r "$K -n campusdesk get configmap campusdesk-config -o jsonpath='{.data.SUPPORT_BANNER}'; echo"
r "sleep 5; curl -s http://campusdesk.localhost:8088/api/info | jq -r .banner"
note "selfHeal: a manual change is reverted to what Git says"
r "$K -n campusdesk scale deploy campusdesk-frontend --replicas=1"
sleep 20
r "$K -n campusdesk get deploy campusdesk-frontend"
r "$K -n argocd get application campusdesk -o jsonpath='{.status.operationState.message}'; echo"
