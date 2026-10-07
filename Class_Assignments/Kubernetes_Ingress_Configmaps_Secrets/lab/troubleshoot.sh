#!/bin/bash
# Session 12 Task 5: troubleshooting. Usage: lab/troubleshoot.sh <step> > lab/<step>.txt
# Needs the ingress-nginx port-forward on 127.0.0.1:18081 from run.sh step 12.
source ~/devops-lab/k8s-a/common.sh
cd "$(dirname "$0")/../troubleshooting"
N='kubectl -n troubleshoot'
CURL='curl -s -o /dev/null -w "HTTP %{http_code}\n" -H "Host: orders.local" http://127.0.0.1:18081/'
case $1 in
40-before)
  r kubectl apply -f broken/app.yaml
  r 'sleep 20'
  c 'the reported problem:'
  r "$CURL"
  r 'curl -s -H "Host: orders.local" http://127.0.0.1:18081/ | grep -o "<title>.*</title>"'
  r "$N get deploy,rs,pods,svc,ingress" ;;
41-diagnose-pods)
  c 'layer 1: why are the pods not running?'
  r "$N describe pod -l app=orders | grep -E '^Name:|State:|Reason:' | head -4"
  r "$N get events --field-selector reason=Failed -o custom-columns=OBJECT:.involvedObject.name,MESSAGE:.message | head -3"
  r "$N get secret orders-db -o jsonpath='{.data}'; echo"
  r "$N get deploy orders -o jsonpath='{range .spec.template.spec.containers[0].env[*]}{.name} <- secret {.valueFrom.secretKeyRef.name} key {.valueFrom.secretKeyRef.key}{\"\\n\"}{end}'" ;;
42-diagnose-ingress)
  c 'layer 2: where does the Ingress send traffic?'
  r "$N describe ingress orders | sed -n '/^Rules:/,/^Annotations:/p'"
  r "$N get svc"
  r "kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --since=10m | grep -i 'orders-svc' | tail -2 | cut -c1-180" ;;
43-fix-1-2)
  c 'FIX 1: Deployment asks for key DB_PASSWORD, the Secret only has DB_USER and DB_PASS'
  r "$N patch deployment orders --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env/1/valueFrom/secretKeyRef/key\",\"value\":\"DB_PASS\"}]'"
  r "$N rollout status deployment/orders --timeout=180s"
  r "$N get pods -l app=orders"
  c 'FIX 2: Ingress backend points at Service "orders-svc", the real name is "orders-service"'
  r "$N patch ingress orders --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/rules/0/http/paths/0/backend/service/name\",\"value\":\"orders-service\"}]'"
  r 'sleep 5'
  r "$CURL"
  c 'progress: 503 (no backend) became 502 (backend exists but the connection fails)' ;;
44-diagnose-502)
  c 'layer 3: Service -> pod port'
  r "$N describe ingress orders | grep -A1 'orders.local' | tail -1"
  r "$N get endpointslices"
  r "$N get pods -l app=orders -o jsonpath='{.items[0].spec.containers[0].ports[0].containerPort}'; echo '  <- containerPort'"
  r "$N get svc orders-service -o jsonpath='{.spec.ports[0].targetPort}'; echo '  <- Service targetPort'"
  r "kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --since=2m | grep -E 'connect\\(\\) failed' | tail -1 | cut -c1-200"
  r 'POD_IP=$(kubectl -n troubleshoot get pods -l app=orders -o jsonpath="{.items[0].status.podIP}"); kubectl -n troubleshoot run tmp-curl --image=curlimages/curl:8.10.1 --rm -i --restart=Never --quiet -- sh -c "curl -s -m 3 http://orders-service/ || echo via Service port 80 to pod 8080: curl exit \$?; echo -n direct to pod $POD_IP:5000 gives: ; curl -s -m 3 http://$POD_IP:5000/"' ;;
45-fix-3-after)
  c 'FIX 3: Service targetPort 8080 -> 5000 (the port the app really listens on)'
  r "$N patch service orders-service -p '{\"spec\":{\"ports\":[{\"port\":80,\"targetPort\":5000}]}}'"
  r "$N get endpointslices"
  r 'sleep 3'
  c 'AFTER: the original request'
  r "$CURL"
  r 'curl -s -H "Host: orders.local" http://127.0.0.1:18081/'
  r "$N get deploy,pods,svc,ingress"
  c 'the patched live objects now match troubleshooting/fixed/app.yaml (no diff = nothing left to change)'
  r 'kubectl diff -f fixed/app.yaml && echo "kubectl diff: no differences"' ;;
esac
