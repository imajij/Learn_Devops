#!/bin/bash
# Deployment strategies lab (Session 10, Task 1). Usage: lab/strategies.sh <step> > lab/<step>.txt
# YAML files are in ../deployment-strategies/ (taken from the instructor's Kubernetes_Objects folder).
source ~/devops-lab/k8s-a/common.sh
cd "$(dirname "$0")/../deployment-strategies"
# watch pods of one app in the background, one timestamped line per change
watch_start(){ (kubectl get pods -l app=$1 -w --no-headers -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.containerStatuses[0].ready,DELETING:.metadata.deletionTimestamp | while read l; do echo "$(date +%H:%M:%S) $l"; done > ~/devops-lab/k8s-a/watch-$1.log) & }
watch_stop(){ sleep 2; pkill -f "kubectl get pods -l app=$1 -w"; sleep 1; }
case $1 in
00-client)
  r 'kubectl run client --image=curlimages/curl:8.10.1 -- sleep 36000'
  r kubectl wait --for=condition=Ready pod/client --timeout=120s ;;
01-rolling-v1)
  r 'grep -A4 "strategy:" 01-rolling-update/deployment-v1.yaml'
  r kubectl apply -f 01-rolling-update/deployment-v1.yaml -f 01-rolling-update/service.yaml
  r kubectl rollout status deployment/app-rolling --timeout=180s
  r kubectl get deploy,rs,pods -l app=app-rolling -L version
  r 'kubectl exec client -- curl -s http://app-rolling-service | grep -o "VERSION: v[0-9]"' ;;
02-rolling-update)
  r 'diff 01-rolling-update/deployment-v1.yaml 01-rolling-update/deployment-v2.yaml | grep -E "^[<>].*(version|image|VERSION)"'
  c 'start a background curl loop (1 request / 0.3 s) and a pod watch, then apply v2'
  r '(kubectl exec client -- sh -c "for i in \$(seq 1 150); do curl -s -m 1 http://app-rolling-service | grep -o \"VERSION: v[0-9]\" || echo FAILED; sleep 0.3; done" > ~/devops-lab/k8s-a/rolling-curl.log &) ; echo started'
  watch_start app-rolling; sleep 2
  r kubectl apply -f 01-rolling-update/deployment-v2.yaml
  r kubectl rollout status deployment/app-rolling --timeout=180s
  watch_stop app-rolling
  r kubectl get rs -l app=app-rolling -L version
  r kubectl get pods -l app=app-rolling -L version
  r 'kubectl rollout history deployment/app-rolling' ;;
03-rolling-observed)
  r 'until [ $(wc -l < ~/devops-lab/k8s-a/rolling-curl.log) -ge 150 ]; do sleep 2; done; uniq -c ~/devops-lab/k8s-a/rolling-curl.log'
  c 'pod watch during the update, only lines where a pod changed (time, pod, phase, ready, being-deleted?)'
  r "awk '{d=(\$5==\"<none>\")?\"-\":\"TERMINATING\"; s=\$3\" \"\$4\" \"d; if(last[\$2]!=s){printf \"%s %-30s %-9s %-6s %s\\n\",\$1,\$2,\$3,\$4,d; last[\$2]=s}}' ~/devops-lab/k8s-a/watch-app-rolling.log"
  ;;   # cleanup was done by hand: kubectl delete -f 01-rolling-update/
04-bluegreen-deploy)
  r kubectl apply -f 02-blue-green/deployment-blue.yaml -f 02-blue-green/deployment-green.yaml -f 02-blue-green/service-blue.yaml
  r kubectl rollout status deployment/app-blue --timeout=180s
  r kubectl rollout status deployment/app-green --timeout=180s
  r kubectl get pods -l app=myapp -L slot,version -o wide
  r 'kubectl get svc myapp-service -o jsonpath="{.spec.selector}"; echo'
  r 'kubectl get endpointslices -l kubernetes.io/service-name=myapp-service'
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 10); do curl -s http://myapp-service | grep -o \"[A-Z]* ENVIRONMENT\"; done" | sort | uniq -c' ;;
05-bluegreen-switch)
  r 'diff 02-blue-green/service-blue.yaml 02-blue-green/service-green.yaml | grep slot'
  r kubectl apply -f 02-blue-green/service-green.yaml
  r 'kubectl get svc myapp-service -o jsonpath="{.spec.selector}"; echo'
  r 'kubectl get endpointslices -l kubernetes.io/service-name=myapp-service'
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 10); do curl -s http://myapp-service | grep -o \"[A-Z]* ENVIRONMENT\"; done" | sort | uniq -c'
  c 'instant rollback = switch the selector back'
  r "kubectl patch svc myapp-service -p '{\"spec\":{\"selector\":{\"slot\":\"blue\"}}}'"
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 10); do curl -s http://myapp-service | grep -o \"[A-Z]* ENVIRONMENT\"; done" | sort | uniq -c'
  c 'same test again 3 seconds later (kube-proxy updates its rules asynchronously):'
  r 'sleep 3; kubectl exec client -- sh -c "for i in \$(seq 1 10); do curl -s http://myapp-service | grep -o \"[A-Z]* ENVIRONMENT\"; done" | sort | uniq -c'
  r kubectl apply -f 02-blue-green/service-green.yaml
  c 'green is live and verified, so blue is scaled to 0 (kept for a quick rollback)'
  r kubectl scale deployment app-blue --replicas=0
  r kubectl get deploy -l app=myapp -L slot,version
  r kubectl delete deployment/app-blue deployment/app-green service/myapp-service ;;
06-canary-deploy)
  r kubectl apply -f 03-canary/deployment-stable.yaml -f 03-canary/service.yaml
  r kubectl rollout status deployment/app-stable --timeout=240s
  r kubectl apply -f 03-canary/deployment-canary.yaml
  r kubectl rollout status deployment/app-canary --timeout=180s
  r kubectl get deploy -l app=myapp-canary -L track,version
  r 'kubectl get pods -l app=myapp-canary -L track --no-headers | awk "{print \$NF}" | sort | uniq -c'
  r 'kubectl get svc myapp-canary-service -o jsonpath="{.spec.selector}"; echo'
  r 'kubectl get endpointslices -l kubernetes.io/service-name=myapp-canary-service -o jsonpath="{range .items[*].endpoints[*]}{.addresses[0]}{\"\\n\"}{end}" | wc -l' ;;
07-canary-traffic)
  c '100 requests through the single Service (9 stable pods + 1 canary pod)'
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 100); do curl -s http://myapp-canary-service | grep -oE \"(STABLE|CANARY) v[0-9]\"; done" | sort | uniq -c'
  c 'second sample of 100 to show the variation'
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 100); do curl -s http://myapp-canary-service | grep -oE \"(STABLE|CANARY) v[0-9]\"; done" | sort | uniq -c'
  c 'canary looks healthy -> increase to 50 %: 5 stable + 5 canary'
  r 'kubectl scale deployment app-stable --replicas=5 && kubectl scale deployment app-canary --replicas=5'
  r 'kubectl rollout status deployment/app-canary --timeout=180s; kubectl wait --for=delete pod -l track=stable --field-selector=status.phase!=Running --timeout=60s 2>/dev/null; sleep 5'
  r 'kubectl get pods -l app=myapp-canary -L track --no-headers | awk "{print \$NF}" | sort | uniq -c'
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 100); do curl -s http://myapp-canary-service | grep -oE \"(STABLE|CANARY) v[0-9]\"; done" | sort | uniq -c'
  r kubectl delete -f 03-canary/ ;;
08-recreate)
  r 'grep -A1 "strategy:" 04-recreate/deployment-v1.yaml'
  r kubectl apply -f 04-recreate/deployment-v1.yaml -f 04-recreate/service.yaml
  r kubectl rollout status deployment/app-recreate --timeout=180s
  r kubectl get pods -l app=app-recreate -L version
  r '(kubectl exec client -- sh -c "for i in \$(seq 1 60); do echo \$(date +%H:%M:%S) \$(curl -s -m 1 http://app-recreate-service | grep -o \"VERSION: v[0-9]\" || echo NO-RESPONSE); sleep 0.5; done" > ~/devops-lab/k8s-a/recreate-curl.log &) ; echo started curl loop'
  watch_start app-recreate; sleep 3
  r 'date +%H:%M:%S; kubectl apply -f 04-recreate/deployment-v2.yaml'
  r kubectl rollout status deployment/app-recreate --timeout=180s
  watch_stop app-recreate
  r kubectl get pods -l app=app-recreate -L version
  r 'kubectl describe deployment app-recreate | sed -n "/^Events:/,\$p"' ;;
09-recreate-observed)
  c 'pod watch during the update, only lines where a pod changed (time, pod, phase, ready, being-deleted?)'
  r "awk '{d=(\$5==\"<none>\")?\"-\":\"TERMINATING\"; s=\$3\" \"\$4\" \"d; if(last[\$2]!=s){printf \"%s %-30s %-9s %-6s %s\\n\",\$1,\$2,\$3,\$4,d; last[\$2]=s}}' ~/devops-lab/k8s-a/watch-app-recreate.log"
  r 'until [ $(wc -l < ~/devops-lab/k8s-a/recreate-curl.log) -ge 60 ]; do sleep 2; done; uniq -c -f1 ~/devops-lab/k8s-a/recreate-curl.log | head -20'
  r kubectl delete deployment/app-recreate service/app-recreate-service ;;
esac
