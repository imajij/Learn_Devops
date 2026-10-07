#!/usr/bin/env bash
# Step 6: PVC keeps data across a database pod restart; HPA scales the backend under load.
source "$(dirname "$0")/common.sh"
U=http://campusdesk.localhost:8088/api/tickets
note "create tickets through the Ingress"
for d in '{"title":"Lab 3 printer jammed","category":"HARDWARE","priority":"HIGH","requester":"Ajij Uttam","location":"CS Lab 3"}' \
         '{"title":"Wi-Fi drops on Library 2nd floor","category":"NETWORK","priority":"URGENT","requester":"Riya Sharma","location":"Library L2"}' \
         '{"title":"Reset LMS password","category":"ACCOUNT","priority":"MEDIUM","requester":"Kabir Singh","location":"Hostel C"}' \
         '{"title":"Install Python 3.12 on lab PCs","category":"SOFTWARE","priority":"LOW","requester":"Prof. Mehta","location":"CS Lab 1"}'; do
  r "curl -s -o /dev/null -w 'HTTP %{http_code}\n' -X POST $U -H 'Content-Type: application/json' -d '$d'"
done
r "curl -s -X PUT $U/3 -H 'Content-Type: application/json' -d '{\"status\":\"IN_PROGRESS\"}' | jq -c '{id,status}'"
r "curl -s $U/stats; echo"
note "kill the database pod - the PVC (and the tickets) must survive"
r "$K -n campusdesk delete pod -l app=campusdesk-postgres --wait=true"
r "$K -n campusdesk rollout status deploy/campusdesk-postgres --timeout=120s"
r "$K -n campusdesk get pods -l app=campusdesk-postgres"
r "sleep 8; curl -s $U | jq -r '.[] | \"#\\(.id) \\(.status) \\(.title)\"'"
r "$K -n campusdesk exec deploy/campusdesk-postgres -- sh -c 'psql -U \$POSTGRES_USER -d \$POSTGRES_DB -c \"select id, priority, status, title from tickets order by id\"'"
r "$K -n campusdesk exec deploy/campusdesk-postgres -- df -h /var/lib/postgresql/data"
r "$K get pv -o custom-columns=PV:.metadata.name,CLAIM:.spec.claimRef.name,SIZE:.spec.capacity.storage,CLASS:.spec.storageClassName,PATH:.spec.hostPath.path"
