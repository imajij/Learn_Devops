#!/usr/bin/env bash
# Step 6b: generate CPU load on the backend and watch the HPA scale it out (min 2, max 5, 60% CPU).
source "$(dirname "$0")/common.sh"
r "$K top pods -n campusdesk -l app=campusdesk-backend"
r "$K -n campusdesk get hpa campusdesk-backend"
note "start a load generator: 12 parallel loops hitting the API inside the cluster"
r "$K -n campusdesk run loadgen --image=postgres:17-alpine --restart=Never --command -- sh -c 'for i in \$(seq 12); do (while true; do wget -q -O /dev/null http://campusdesk-backend:8000/api/tickets/stats; done) & done; sleep 150'"
for i in 1 2 3 4 5 6; do
  sleep 25
  r "$K -n campusdesk get hpa campusdesk-backend --no-headers"
done
r "$K -n campusdesk get pods -l app=campusdesk-backend"
r "$K -n campusdesk describe hpa campusdesk-backend | sed -n '/Events/,\$p'"
r "$K -n campusdesk delete pod loadgen --wait=false"
