#!/usr/bin/env bash
# Troubleshooting 3/6: readiness probe on a wrong path -> pod Running but never Ready
source "$(dirname "$0")/common.sh"; cd "$APP"; NS="-n campusdesk"; H="helm --kube-context final"
note "BREAK: release with readinessPath=/readiness"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values -f kubernetes/troubleshooting/03-failing-probe.values.yaml | grep -E 'STATUS|REVISION'"
sleep 45
note "1 IDENTIFY"
r "$K $NS get pods -l app=campusdesk-backend"
r "$K $NS rollout status deploy/campusdesk-backend --timeout=5s"
note "2 INVESTIGATE"
NEW=$($K -n campusdesk get pods -l app=campusdesk-backend --sort-by=.metadata.creationTimestamp -o name | tail -1)
r "$K $NS describe $NEW | grep -E '^ +Readiness|Unhealthy' | cut -c1-200"
r "$K $NS logs $NEW -c api --tail=3 | cut -c1-160"
r "$K $NS exec $NEW -c api -- python -c \"import urllib.request as u
for p in ('/readiness','/ready'):
    try: print(p, u.urlopen('http://127.0.0.1:8000'+p).status)
    except Exception as e: print(p, e)\""
note "3 ROOT CAUSE: the app is healthy, but the probe asks for /readiness which returns 404; the API's readiness endpoint is /ready"
note "4 FIX: correct the value (reuse-values would keep the bad path) and roll out"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values --set backend.probes.readinessPath=/ready --wait | grep -E 'STATUS|REVISION'"
note "5 VERIFY"
sleep 15
r "$K $NS get pods -l app=campusdesk-backend"
r "$K $NS describe deploy campusdesk-backend | grep Readiness"
