#!/usr/bin/env bash
# Troubleshooting 6/6: Ingress sends /api to the wrong Service port (the bug in the session21 sample chart)
source "$(dirname "$0")/common.sh"; cd "$APP"; NS="-n campusdesk"; H="helm --kube-context final"
note "BREAK: /api backend port changed to 8080 (the instructor's sample ingress.yaml used 8080)"
r "$K $NS patch ingress campusdesk --type=json --patch-file kubernetes/troubleshooting/06-ingress-wrong-port.patch.json"
sleep 8
note "1 IDENTIFY: the UI (/) still loads, every /api call fails"
r "curl -s -o /dev/null -w '/          -> HTTP %{http_code}\n' http://campusdesk.localhost:8088/"
r "curl -s -o /dev/null -w '/api/info  -> HTTP %{http_code}\n' http://campusdesk.localhost:8088/api/info"
note "2 INVESTIGATE"
r "$K $NS describe ingress campusdesk | sed -n '/Rules/,/Annotations/p'"
r "$K $NS get svc campusdesk-backend -o custom-columns=NAME:.metadata.name,PORT:.spec.ports[0].port,TARGET:.spec.ports[0].targetPort"
r "$K -n ingress-nginx logs deploy/ingress-nginx-controller --since=40s | grep -E 'GET /api/info' | tail -1 | cut -c1-200"
note "3 ROOT CAUSE: the Service only exposes port 8000; port 8080 has no endpoints, so ingress-nginx has no upstream and answers 503"
note "4 FIX: re-apply the chart (port comes from backend.port = 8000)"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values --force-conflicts --wait | grep -E 'STATUS|REVISION'"
note "5 VERIFY"
r "$K $NS get ingress campusdesk -o jsonpath='{range .spec.rules[0].http.paths[*]}{.path} -> {.backend.service.name}:{.backend.service.port.number}{\"\\n\"}{end}'"
r "sleep 5; curl -s -w '  <- HTTP %{http_code}\n' http://campusdesk.localhost:8088/api/info"
