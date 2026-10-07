#!/usr/bin/env bash
# Troubleshooting 4/6: Service selector does not match the pod labels -> no endpoints -> 503
source "$(dirname "$0")/common.sh"; cd "$APP"; NS="-n campusdesk"; H="helm --kube-context final"
note "BREAK: Service selector changed to app=campusdesk-api"
r "$K $NS patch svc campusdesk-backend --patch-file kubernetes/troubleshooting/04-service-selector.patch.yaml"
sleep 5
note "1 IDENTIFY: users get errors, but every pod is Running and Ready"
r "curl -s -w '  <- HTTP %{http_code}\n' http://campusdesk.localhost:8088/api/tickets/stats"
r "$K $NS get pods -l app=campusdesk-backend"
[ -n "${SHOT:-}" ] && ego-browser nodejs <<JS >/dev/null
const task = await taskSpace(24); const page = task.page("p1");
await page.cdp("Emulation.setDeviceMetricsOverride",{width:1280,height:800,deviceScaleFactor:1,mobile:false});
await page.goto("http://campusdesk.localhost:8088/"); await page.waitForTimeout(2500);
await page.screenshot({ path: "$PROJ/images/09-t4-ui-broken-service.png" });
JS
note "2 INVESTIGATE"
r "$K $NS get endpointslices -l kubernetes.io/service-name=campusdesk-backend"
r "$K $NS get svc campusdesk-backend -o jsonpath='{.spec.selector}'; echo"
r "$K $NS get pods -l tier=api -o custom-columns=POD:.metadata.name,APP_LABEL:.metadata.labels.app"
r "$K -n ingress-nginx logs deploy/ingress-nginx-controller --since=60s | grep -m1 'does not have any active Endpoint'"
note "3 ROOT CAUSE: selector app=campusdesk-api matches no pod (pods are labelled app=campusdesk-backend) -> 0 endpoints -> ingress returns 503"
note "4 FIX: re-apply the chart, taking the selector field back from the kubectl-patch manager"
r "$H upgrade campusdesk helm/campusdesk $NS --reuse-values --force-conflicts --wait | grep -E 'STATUS|REVISION'"
note "5 VERIFY"
r "$K $NS get endpointslices -l kubernetes.io/service-name=campusdesk-backend"
note "(the ingress controller picks up new endpoints within a few seconds)"
r "sleep 5; curl -s -w '  <- HTTP %{http_code}\n' http://campusdesk.localhost:8088/api/tickets/stats"
