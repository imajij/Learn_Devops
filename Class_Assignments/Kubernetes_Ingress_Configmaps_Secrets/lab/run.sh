#!/bin/bash
# Session 12 lab. Usage: lab/run.sh <step> > lab/<step>.txt
source ~/devops-lab/k8s-a/common.sh
cd "$(dirname "$0")/.."
case $1 in
01-configmap-create)
  r kubectl apply -f configmap/configmap.yaml
  r kubectl get configmap yatri-app-config
  r kubectl describe configmap yatri-app-config
  r "kubectl get configmap yatri-app-config -o jsonpath='{.data.ENVIRONMENT}'; echo"
  c 'the same thing imperatively (dry run, not applied):'
  r 'kubectl create configmap demo-cm --from-literal=LOG_LEVEL=DEBUG --from-file=app.properties=<(printf "a=1\n") --dry-run=client -o yaml' ;;
02-configmap-pod)
  r kubectl apply -f configmap/pod.yaml
  r kubectl wait --for=condition=Ready pod/configmap-demo --timeout=90s
  c 'env vars inside the container (envFrom + single key):'
  r "kubectl exec configmap-demo -- sh -c 'env | sort | grep -E \"ENVIRONMENT|LOG_LEVEL|APP_PORT|CURRENCY|BOOKING\"'"
  c 'files inside the container (volume):'
  r 'kubectl exec configmap-demo -- ls -l /etc/yatri'
  r 'kubectl exec configmap-demo -- cat /etc/yatri/app.properties'
  r 'kubectl exec configmap-demo -- cat /etc/yatri/LOG_LEVEL; echo' ;;
03-configmap-update)
  c 'change a value: env vars are fixed at container start, mounted files are refreshed by the kubelet'
  r "kubectl patch configmap yatri-app-config --type merge -p '{\"data\":{\"LOG_LEVEL\":\"DEBUG\"}}'"
  r 'date +%T; until [ "$(kubectl exec configmap-demo -- cat /etc/yatri/LOG_LEVEL)" = DEBUG ]; do sleep 2; done; date +%T'
  r 'kubectl exec configmap-demo -- cat /etc/yatri/LOG_LEVEL; echo'
  r "kubectl exec configmap-demo -- sh -c 'echo LOG_LEVEL=\$LOG_LEVEL CURRENT_LOG_LEVEL=\$CURRENT_LOG_LEVEL'"
  c 'restart the pod to pick up the new env value'
  r 'kubectl delete pod configmap-demo && kubectl apply -f configmap/pod.yaml && kubectl wait --for=condition=Ready pod/configmap-demo --timeout=90s'
  r "kubectl exec configmap-demo -- sh -c 'echo LOG_LEVEL=\$LOG_LEVEL CURRENT_LOG_LEVEL=\$CURRENT_LOG_LEVEL'"
  r "kubectl patch configmap yatri-app-config --type merge -p '{\"data\":{\"LOG_LEVEL\":\"INFO\"}}'"
  r 'kubectl delete pod configmap-demo --grace-period=1' ;;
04-secret-create)
  c 'base64 gotcha: echo adds a newline that ends up inside the secret'
  r 'echo "demo-only-not-a-real-password" | base64'
  r 'echo -n "demo-only-not-a-real-password" | base64'
  r kubectl apply -f secret/secret.yaml
  r kubectl get secret yatri-db-secret
  r kubectl describe secret yatri-db-secret
  c 'base64 is encoding, not encryption: anyone who can read the object can decode it'
  r "kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}'; echo"
  r "kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 --decode; echo"
  c 'imperative alternative that avoids hand-made base64 (dry run, not applied):'
  r 'kubectl create secret generic demo-secret --from-literal=API_KEY=fake-demo-key-123 --dry-run=client -o yaml' ;;
05-secret-pod)
  r kubectl apply -f secret/pod.yaml
  r kubectl wait --for=condition=Ready pod/secret-demo --timeout=90s
  r "kubectl exec secret-demo -- sh -c 'echo DB_USER=\$DB_USER; echo DB_PASSWORD=\$DB_PASSWORD'"
  r 'kubectl exec secret-demo -- ls -lL /etc/db-creds'
  r 'kubectl exec secret-demo -- cat /etc/db-creds/POSTGRES_PASSWORD; echo'
  r "kubectl exec secret-demo -- sh -c 'mount | grep db-creds'"
  c 'where the secret actually lives: etcd, readable by anyone with get-secret RBAC or etcd access'
  r 'kubectl auth can-i get secrets; kubectl auth can-i get secrets --as=system:serviceaccount:default:default'
  r 'kubectl delete pod secret-demo --grace-period=1' ;;
06-secret-git)
  c 'would this file be caught before reaching GitHub? scan it with gitleaks (secret scanner)'
  r 'gitleaks version'
  r 'gitleaks dir secret/ --no-banner --no-color -v 2>&1 | grep -E "RuleID|File|Line|Secret:|leaks found"'
  c 'both findings are the intentionally FAKE demo values -> mark exactly those lines as allowed, rescan'
  r "sed -i '' 's/^kind: Secret\$/kind: Secret  # gitleaks:allow (fake demo values)/; s/^\\(  POSTGRES_PASSWORD: [A-Za-z0-9=]*\\)\$/\\1  # gitleaks:allow/' secret/secret.yaml; grep -n gitleaks:allow secret/secret.yaml"
  r 'gitleaks dir secret/ --no-banner --no-color 2>&1 | tail -1' ;;
10-ingress-apps)
  r kubectl apply -f ingress/backend.yaml -f ingress/frontend.yaml
  r kubectl rollout status deployment/yatri-backend --timeout=180s
  r kubectl rollout status deployment/yatri-frontend --timeout=180s
  r "kubectl get pods -l 'app in (yatri-backend,yatri-frontend)' -o wide"
  r kubectl get svc yatri-backend-service yatri-frontend-service
  c 'the backend got its config from the ConfigMap and Secret:'
  r "kubectl exec deploy/yatri-backend -- sh -c 'env | sort | grep -E \"ENVIRONMENT|LOG_LEVEL|CURRENCY|POSTGRES_(USER|DB)\"'" ;;
11-ingress-create)
  r kubectl apply -f ingress/ingress.yaml -f ingress/ingress-hosts.yaml
  r 'until kubectl get ingress yatri-ingress -o jsonpath="{.status.loadBalancer.ingress[0].ip}" | grep -q .; do sleep 2; done; kubectl get ingress'
  r kubectl describe ingress yatri-ingress
  r "kubectl describe ingress yatri-hosts | sed -n '/^Rules:/,/^Annotations:/p'" ;;
12-ingress-routing)
  c 'reach the ingress-nginx controller from the Mac: port-forward its Service (port 18081 -> 80)'
  r '(kubectl -n ingress-nginx port-forward svc/ingress-nginx-controller 18081:80 > ~/devops-lab/k8s-a/pf.log 2>&1 &); until grep -q Forwarding ~/devops-lab/k8s-a/pf.log; do sleep 1; done; cat ~/devops-lab/k8s-a/pf.log'
  c 'path routing on host yatri.local'
  r 'curl -s -H "Host: yatri.local" http://127.0.0.1:18081/ | grep -o "<title>.*</title>"'
  r 'curl -s -H "Host: yatri.local" http://127.0.0.1:18081/api/'
  c 'host routing: api.yatri.local goes straight to the backend'
  r 'curl -s -H "Host: api.yatri.local" http://127.0.0.1:18081/ | head -3'
  c 'unknown host -> no rule matches -> controller default backend'
  r 'curl -s -o /dev/null -w "%{http_code}\n" -H "Host: unknown.local" http://127.0.0.1:18081/'
  r 'curl -s -H "Host: unknown.local" http://127.0.0.1:18081/ | grep -o "<title>.*</title>"'
  c 'the controller access log proves every request went through it'
  r "kubectl -n ingress-nginx logs deploy/ingress-nginx-controller --since=60s | grep -E '\"GET' | awk '{print \$7, \$9, \$(NF-4), \$(NF-3)}' | tail -6" ;;
13-ingress-controller-view)
  c 'what the controller did with the Ingress objects: generated nginx.conf'
  r "kubectl -n ingress-nginx exec deploy/ingress-nginx-controller -- sh -c 'grep -E \"server_name \\\"\" /etc/nginx/nginx.conf'"
  r "kubectl -n ingress-nginx exec deploy/ingress-nginx-controller -- sh -c 'grep -E \"location ~\\* \" /etc/nginx/nginx.conf | head -4'"
  r "kubectl -n ingress-nginx get deploy ingress-nginx-controller -o jsonpath='{.spec.template.spec.containers[0].args}' | tr ',' '\\n' | head -12" ;;
esac
