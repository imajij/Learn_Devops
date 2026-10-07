#!/usr/bin/env bash
# Troubleshooting 5/6: backend pods without CPU requests -> HPA cannot scale
source "$(dirname "$0")/common.sh"; cd "$APP"; NS="-n campusdesk"; H="helm --kube-context final"
note "BREAK: release with backend.resources removed"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values -f kubernetes/troubleshooting/05-hpa-no-requests.values.yaml --wait | grep -E 'STATUS|REVISION'"
sleep 50
note "1 IDENTIFY"
r "$K $NS get hpa campusdesk-backend"
note "2 INVESTIGATE"
r "$K $NS describe hpa campusdesk-backend | grep -E 'ScalingActive|FailedGetResourceMetric' | tail -2 | cut -c1-230"
r "$K $NS get deploy campusdesk-backend -o jsonpath='{.spec.template.spec.containers[0].resources}'; echo '<- empty'"
r "$K top pods $NS -l app=campusdesk-backend"
note "3 ROOT CAUSE: HPA target is a % of the CPU *request*. No request -> no denominator -> utilisation unknown -> no scaling (metrics-server itself is fine, see kubectl top)"
note "4 FIX: give the container its requests/limits back"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values --set-json 'backend.resources={\"requests\":{\"cpu\":\"100m\",\"memory\":\"128Mi\"},\"limits\":{\"cpu\":\"500m\",\"memory\":\"256Mi\"}}' --wait | grep -E 'STATUS|REVISION'"
sleep 60
note "5 VERIFY"
r "$K $NS get hpa campusdesk-backend"
r "$K $NS describe hpa campusdesk-backend | grep -E 'ScalingActive'"
