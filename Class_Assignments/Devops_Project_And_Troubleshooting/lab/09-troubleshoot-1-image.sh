#!/usr/bin/env bash
# Troubleshooting 1/6: bad image tag -> ImagePullBackOff
source "$(dirname "$0")/common.sh"; cd "$APP"; NS="-n campusdesk"; H="helm --kube-context final"
note "BREAK: helm upgrade with a backend tag that was never pushed"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values -f kubernetes/troubleshooting/01-bad-image-tag.values.yaml | grep -E 'STATUS|REVISION'"
sleep 40
note "1 IDENTIFY"
r "$K $NS get pods -l app=campusdesk-backend"
note "2 INVESTIGATE"
r "$K $NS describe \$($K $NS get pods -l app=campusdesk-backend --field-selector=status.phase=Pending -o name | head -1) | grep -E 'Image:|Reason|Failed|Back-off' | cut -c1-230"
r "curl -s localhost:5060/v2/ajij/campusdesk-backend/tags/list; echo"
note "3 ROOT CAUSE: tag 9e8f63b does not exist in the registry (CI pushed 9e8f63a). Old pods keep serving because the rolling update never got a Ready new pod:"
r "curl -s -o /dev/null -w 'ingress /api/info -> HTTP %{http_code}\n' http://campusdesk.localhost:8088/api/info"
note "4 FIX: roll back to the last good Helm revision"
r "$H history campusdesk $NS --max 2 | cut -c1-100"
r "$H rollback campusdesk $NS --wait   # no revision = the previous one"
note "5 VERIFY"
r "$K $NS rollout status deploy/campusdesk-backend --timeout=120s"
sleep 20
r "$K $NS get pods -l app=campusdesk-backend -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready"
