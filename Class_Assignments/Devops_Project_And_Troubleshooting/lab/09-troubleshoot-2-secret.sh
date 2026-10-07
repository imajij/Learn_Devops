#!/usr/bin/env bash
# Troubleshooting 2/6: Deployment references a Secret key that does not exist -> CreateContainerConfigError
source "$(dirname "$0")/common.sh"; cd "$APP"; NS="-n campusdesk"; H="helm --kube-context final"
note "BREAK: someone hand-edits the Deployment: DB_PASSWORD now reads key 'password' instead of 'db-password'"
r "$K $NS patch deploy campusdesk-backend --type=json --patch-file kubernetes/troubleshooting/02-wrong-secret-key.patch.json"
sleep 25
note "1 IDENTIFY"
r "$K $NS get pods -l app=campusdesk-backend"
note "2 INVESTIGATE"
r "$K $NS get events --field-selector reason=Failed --sort-by=.lastTimestamp | tail -2 | cut -c1-200"
r "$K $NS get deploy campusdesk-backend -o jsonpath='{.spec.template.spec.containers[0].env[1]}' | jq -c ."
r "$K $NS get secret campusdesk-db -o json | jq -c '.data | keys'"
note "3 ROOT CAUSE: Secret campusdesk-db has keys db-user/db-password; the pod asks for 'password', so the kubelet cannot build the env and refuses to start the container"
note "4 FIX: re-apply the chart (the source of truth) - Helm puts the correct key back"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values --wait 2>&1 | grep -E 'STATUS|REVISION|Error' | cut -c1-260"
note "Helm 4 uses server-side apply: the field is now owned by the 'kubectl-patch' manager, so Helm refuses to overwrite it."
note "That is the drift being reported. Helm's chart is the source of truth, so take the field back explicitly:"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values --force-conflicts --wait | grep -E 'STATUS|REVISION'"
note "5 VERIFY"
r "$K $NS get deploy campusdesk-backend -o jsonpath='{.spec.template.spec.containers[0].env[1].valueFrom.secretKeyRef.key}'; echo"
sleep 15
r "$K $NS get pods -l app=campusdesk-backend"
r "curl -s http://campusdesk.localhost:8088/api/tickets/stats; echo"
