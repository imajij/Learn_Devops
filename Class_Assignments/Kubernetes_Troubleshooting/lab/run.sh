#!/bin/bash
# Lab script for Session 14 (Kubernetes Troubleshooting). Usage: bash lab/run.sh <step>
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
I=02-issues
case "$1" in
01-setup)
  step 01-setup
  r $K apply -f 01-commands/get-pod.yaml -f 01-commands/logs-pod.yaml
  r $K wait --for=condition=Ready pod/get-demo pod/logs-demo --timeout=180s
  ;;
02-get)
  step 02-get
  r $K get nodes
  r $K get pods
  r $K get pods -A
  r $K get pods --show-labels
  r $K get pods -l app=get-demo
  r "$K get pod get-demo -o jsonpath='{.status.phase} {.status.podIP} {.spec.containers[0].image}{\"\\n\"}'"
  r "$K get pod get-demo -o yaml | sed -n '/^status:/,/hostIP/p'"
  ;;
03-get-wide)
  step 03-get-wide
  r $K get pods -o wide
  r $K get nodes -o wide
  r $K get svc -A -o wide
  ;;
04-describe)
  step 04-describe
  r $K describe pod get-demo
  ;;
05-describe-node)
  step 05-describe-node
  r "$K describe node k8s-b | sed -n '/Conditions:/,/Events:/p' | grep -v '^  kube-\|^  default' | head -60"
  ;;
06-logs)
  step 06-logs
  r $K logs logs-demo --tail=8
  r $K logs logs-demo --since=12s --timestamps
  r $K logs -l app=get-demo --tail=3
  r "timeout 7 $K logs -f logs-demo --tail=1; echo '(stopped follow after 7s)'"
  ;;
07-exec)
  step 07-exec
  r $K exec get-demo -- hostname
  r $K exec get-demo -- nginx -v
  r "$K exec get-demo -- env | grep -E 'HOSTNAME|KUBERNETES_SERVICE_HOST|NGINX_VERSION'"
  r $K exec get-demo -- cat /etc/resolv.conf
  r "$K exec get-demo -- curl -s -o /dev/null -w 'localhost -> HTTP %{http_code}\n' http://localhost"
  r "$K exec get-demo -- sh -c 'tr \"\\\\0\" \" \" < /proc/1/cmdline; echo'"
  r "echo 'ls /usr/share/nginx/html; exit' | $K exec -i get-demo -- sh"
  ;;
08-events)
  step 08-events
  r "$K events | tail -15"
  r $K events --for pod/get-demo
  r "$K get events --sort-by=.lastTimestamp -o custom-columns=LAST:.lastTimestamp,TYPE:.type,REASON:.reason,OBJECT:.involvedObject.name | tail -10"
  r "$K events -A --types=Warning | tail -8"
  ;;
09-explain)
  step 09-explain
  r "$K explain pod.spec.containers.livenessProbe | head -30"
  r "$K explain deployment.spec.strategy"
  r "$K explain service.spec.selector | head -15"
  r "$K explain pod.spec.containers.resources --recursive | head -20"
  ;;
10-top)
  step 10-top
  r $K top nodes
  r $K top pods
  r $K top pods -A --sort-by=cpu
  r $K top pods -n kube-system --containers --sort-by=memory
  ;;
11-cleanup-cmds)
  step 11-cleanup-cmds
  r $K delete -f 01-commands/get-pod.yaml -f 01-commands/logs-pod.yaml --now
  ;;
21-crashloop-before)
  step 21-crashloop-before
  r $K apply -f $I/01-crashloopbackoff/broken-pod.yaml
  c "1) IDENTIFY: watch STATUS and RESTARTS for ~2 minutes"
  for i in $(seq 1 12); do sleep 10; echo "[$(date +%H:%M:%S)] $($K get pod crash-demo --no-headers)"; done
  c "2) INVESTIGATE"
  r "$K describe pod crash-demo | sed -n '/State:/,/Restart Count/p'"
  r "$K describe pod crash-demo | sed -n '/Events/,\$p'"
  r $K logs crash-demo
  r $K logs crash-demo --previous
  ;;
21-crashloop-after)
  step 21-crashloop-after
  c "4) FIX: the command must keep running instead of 'exit 1'"
  r "diff -bB $I/01-crashloopbackoff/broken-pod.yaml $I/01-crashloopbackoff/fixed-pod.yaml"
  r $K delete pod crash-demo --now
  r $K apply -f $I/01-crashloopbackoff/fixed-pod.yaml
  r $K wait --for=condition=Ready pod/crash-demo --timeout=60s
  c "5) VERIFY"
  sleep 15
  r $K get pod crash-demo
  r $K logs crash-demo
  r $K delete pod crash-demo --now
  ;;
22-imagepull-before)
  step 22-imagepull-before
  r $K apply -f $I/02-imagepullbackoff/broken-pod.yaml
  c "1) IDENTIFY (each failed pull shows ErrImagePull, then the kubelet backs off -> ImagePullBackOff)"
  for i in $(seq 1 6); do sleep 6; echo "[$(date +%H:%M:%S)] $($K get pod image-demo --no-headers)"; done
  c "2) INVESTIGATE"
  r "$K describe pod image-demo | grep -E 'Image:|Reason|Message'"
  r "$K events --for pod/image-demo"
  ;;
22-imagepull-after)
  step 22-imagepull-after
  r "diff -bB $I/02-imagepullbackoff/broken-pod.yaml $I/02-imagepullbackoff/fixed-pod.yaml"
  r $K delete pod image-demo --now
  r $K apply -f $I/02-imagepullbackoff/fixed-pod.yaml
  r $K wait --for=condition=Ready pod/image-demo --timeout=120s
  r $K get pod image-demo
  r "$K exec image-demo -- curl -s localhost | grep title"
  r $K delete pod image-demo --now
  ;;
23-errimagepull-before)
  step 23-errimagepull-before
  r $K apply -f $I/03-errimagepull/broken-pod.yaml
  c "1) IDENTIFY: poll the STATUS column every 4 s to catch both states"
  for i in $(seq 1 10); do echo "[$(date +%H:%M:%S)] $($K get pod errpull-demo --no-headers)"; sleep 4; done
  c "2) INVESTIGATE"
  r "$K describe pod errpull-demo | sed -n '/Events/,\$p'"
  ;;
23-errimagepull-after)
  step 23-errimagepull-after
  r "diff -bB $I/03-errimagepull/broken-pod.yaml $I/03-errimagepull/fixed-pod.yaml"
  r $K delete pod errpull-demo --now
  r $K apply -f $I/03-errimagepull/fixed-pod.yaml
  r $K wait --for=condition=Ready pod/errpull-demo --timeout=120s
  r $K get pod errpull-demo
  r $K delete pod errpull-demo --now
  ;;
24-pending-before)
  step 24-pending-before
  r $K apply -f $I/04-pending/broken-pod.yaml -f $I/04-pending/broken-pod-cpu.yaml
  sleep 8
  c "1) IDENTIFY"
  r $K get pods pending-demo pending-cpu-demo -o wide
  c "2) INVESTIGATE: the scheduler explains itself in the Events"
  r "$K describe pod pending-demo | sed -n '/Node-Selectors/p;/Events/,\$p'"
  r "$K describe pod pending-cpu-demo | sed -n '/Requests/,/memory/p;/Events/,\$p'"
  r "$K get nodes --show-labels | tr ',' '\n' | grep hostname"
  r "$K describe node k8s-b | grep -A3 -E '^Allocatable|Allocated resources' "
  ;;
24-pending-after)
  step 24-pending-after
  r "diff -bB $I/04-pending/broken-pod.yaml $I/04-pending/fixed-pod.yaml"
  r "diff -bB $I/04-pending/broken-pod-cpu.yaml $I/04-pending/fixed-pod-cpu.yaml"
  r $K delete pod pending-demo pending-cpu-demo --now
  r $K apply -f $I/04-pending/fixed-pod.yaml -f $I/04-pending/fixed-pod-cpu.yaml
  r $K wait --for=condition=Ready pod/pending-demo pod/pending-cpu-demo --timeout=120s
  r $K get pods pending-demo pending-cpu-demo -o wide
  r $K delete pod pending-demo pending-cpu-demo --now
  ;;
25-creating-before)
  step 25-creating-before
  r $K apply -f $I/05-containercreating/broken-pod.yaml
  sleep 40
  c "1) IDENTIFY"
  r $K get pod web-content-demo
  c "2) INVESTIGATE"
  r "$K describe pod web-content-demo | sed -n '/Volumes:/,/Optional/p;/Events/,\$p'"
  r $K get configmap web-content
  ;;
25-creating-after)
  step 25-creating-after
  c "4) FIX: create the missing ConfigMap (no need to touch the Pod)"
  r $K apply -f $I/05-containercreating/configmap.yaml
  c "the kubelet retries the mount with a back-off, so give it up to 3 minutes"
  r $K wait --for=condition=Ready pod/web-content-demo --timeout=180s
  r $K get pod web-content-demo
  r "$K describe pod web-content-demo | sed -n '/Events/,\$p' | tail -5"
  r $K exec web-content-demo -- curl -s localhost
  r $K delete -f $I/05-containercreating/broken-pod.yaml -f $I/05-containercreating/configmap.yaml --now
  ;;
26-svc-before)
  step 26-svc-before
  r $K apply -f $I/06-service-connectivity/deployment.yaml -f $I/06-service-connectivity/broken-service.yaml
  r $K rollout status deploy/web --timeout=120s
  c "1) IDENTIFY: a client pod cannot reach the Service"
  r $K run client --image=busybox:1.36 --restart=Never -i --rm -- wget -qO- -T 3 http://web-service
  c "2) INVESTIGATE: pods fine? service? endpoints?"
  r $K get pods -l app=web -o wide
  r "$K describe svc web-service | grep -E 'Selector|Port|Endpoints'"
  r $K get endpoints web-service
  r "$K run client --image=busybox:1.36 --restart=Never -i --rm -- sh -c \"wget -qO- -T 3 http://\$($K get pod -l app=web -o jsonpath='{.items[0].status.podIP}'):80 | grep title; wget -qO- -T 3 http://\$($K get pod -l app=web -o jsonpath='{.items[0].status.podIP}'):8080\""
  r "$K get pod -l app=web -o jsonpath='{.items[0].spec.containers[0].ports}{\"\\n\"}'"
  ;;
26-svc-after)
  step 26-svc-after
  r "diff -bB $I/06-service-connectivity/broken-service.yaml $I/06-service-connectivity/service.yaml"
  r $K apply -f $I/06-service-connectivity/service.yaml
  r $K get endpoints web-service
  r "$K run client --image=busybox:1.36 --restart=Never -i --rm -- wget -qO- -T 3 http://web-service 2>/dev/null | grep title"
  ;;
27-dns-image-note)
  step 27-dns-image-note
  c "the course's dns-test-pod.yaml as provided (image dnsutils:1.3)"
  cd $I/07-dns
  r "grep image dns-test-pod-orig.yaml"
  r $K apply -f dns-test-pod-orig.yaml; sleep 20
  r $K get pod dns-test
  r "$K events --for pod/dns-test | tail -4"
  r $K delete pod dns-test --now
  ;;
27-dns-before)
  step 27-dns-before
  r $K apply -f $I/07-dns/broken-dns-pod.yaml
  r $K wait --for=condition=Ready pod/dns-test --timeout=180s
  c "1) IDENTIFY: the Service works by IP, but not by name"
  r $K get svc web-service
  r "$K run client --image=busybox:1.36 --restart=Never -i --rm -- wget -qO- -T 3 http://\$($K get svc web-service -o jsonpath='{.spec.clusterIP}') 2>/dev/null | grep title"
  r $K exec dns-test -- nslookup -timeout=3 -retry=1 web-service
  r "$K exec dns-test -- nslookup -timeout=3 google.com | head -6"
  c "2) INVESTIGATE: is CoreDNS healthy? what resolver does the pod use?"
  r $K get pods -n kube-system -l k8s-app=kube-dns -o wide
  r $K get svc -n kube-system kube-dns
  r $K exec dns-test -- cat /etc/resolv.conf
  r "$K get pod dns-test -o jsonpath='dnsPolicy={.spec.dnsPolicy} dnsConfig={.spec.dnsConfig.nameservers}{\"\\n\"}'"
  r $K exec dns-test -- nslookup -timeout=3 web-service 10.96.0.10
  ;;
27-dns-after)
  step 27-dns-after
  r "diff -bB $I/07-dns/broken-dns-pod.yaml $I/07-dns/dns-test-pod.yaml"
  r $K delete pod dns-test --now
  r $K apply -f $I/07-dns/dns-test-pod.yaml
  r $K wait --for=condition=Ready pod/dns-test --timeout=60s
  r $K exec dns-test -- cat /etc/resolv.conf
  r $K exec dns-test -- nslookup web-service
  r $K exec dns-test -- nslookup web-service.default.svc.cluster.local
  r $K exec dns-test -- nslookup kube-dns.kube-system
  r "$K run client --image=busybox:1.36 --restart=Never -i --rm -- wget -qO- -T 3 http://web-service 2>/dev/null | grep title"
  r "$K logs -n kube-system -l k8s-app=kube-dns --tail=5"
  r $K delete pod dns-test --now
  r $K delete -f $I/06-service-connectivity/deployment.yaml -f $I/06-service-connectivity/service.yaml
  ;;
28-net-before)
  step 28-net-before
  r $K apply -f $I/08-pod-networking/broken-app.yaml -f $I/08-pod-networking/client.yaml
  r $K wait --for=condition=Ready pod/backend pod/client --timeout=120s
  r $K get pods backend client -o wide
  c "1) IDENTIFY: pod-to-pod request fails"
  r "BIP=\$($K get pod backend -o jsonpath='{.status.podIP}'); echo backend IP = \$BIP"
  r $K exec client -- wget -qO- -T 3 http://\$BIP:8080
  c "2) INVESTIGATE: is the network itself fine? (ping works) is the app up? (logs, local request)"
  r $K exec client -- ping -c 2 \$BIP
  r $K logs backend
  r $K exec backend -- wget -qO- -T 3 http://127.0.0.1:8080
  r $K exec backend -- netstat -tln
  ;;
28-net-after)
  step 28-net-after
  r "diff -bB $I/08-pod-networking/broken-app.yaml $I/08-pod-networking/fixed-app.yaml"
  r $K delete pod backend --now
  r $K apply -f $I/08-pod-networking/fixed-app.yaml
  r $K wait --for=condition=Ready pod/backend --timeout=60s
  r $K exec backend -- netstat -tln
  r "BIP=\$($K get pod backend -o jsonpath='{.status.podIP}'); echo backend IP = \$BIP"
  r $K exec client -- wget -qO- -T 3 http://\$BIP:8080
  r $K delete -f $I/08-pod-networking/fixed-app.yaml -f $I/08-pod-networking/client.yaml --now
  ;;
29-config-before)
  step 29-config-before
  r $K apply -f $I/09-configuration/configmap.yaml -f $I/09-configuration/broken-deployment.yaml
  sleep 20
  c "1) IDENTIFY"
  r $K get pods -l app=config-app
  c "2) INVESTIGATE"
  r "$K describe pod -l app=config-app | sed -n '/Environment/,/Mounts/p;/Events/,\$p'"
  r $K logs deploy/config-app
  r "$K get configmap app-config -o jsonpath='{.data}{\"\\n\"}'"
  ;;
29-config-after)
  step 29-config-after
  r "diff -bB $I/09-configuration/broken-deployment.yaml $I/09-configuration/fixed-deployment.yaml"
  r $K apply -f $I/09-configuration/fixed-deployment.yaml
  r $K rollout status deploy/config-app --timeout=60s
  r $K get pods -l app=config-app
  r $K logs deploy/config-app
  r $K delete -f $I/09-configuration/fixed-deployment.yaml -f $I/09-configuration/configmap.yaml
  ;;
40-mp-deploy)
  step 40-mp-deploy
  M=mini-project
  c "1) DEPLOY the application exactly as provided"
  r $K apply -f $M/deployment.yaml -f $M/service.yaml
  r $K rollout status deploy/troubleshooting-app --timeout=120s
  r $K get pods
  r $K get service
  c "2) CHECK THE APPLICATION (pods)"
  r $K get pods -o wide -l app=troubleshooting-app
  r "P=\$($K get pods -l app=troubleshooting-app -o jsonpath='{.items[0].metadata.name}'); echo \$P"
  r "$K describe pod \$P | sed -n '/^Status:/p;/^IP:/p;/Image:/p;/Ready:/p;/Events/,\$p'"
  r $K logs \$P --tail=3
  r "$K exec \$P -- curl -s localhost | grep -i title"
  ;;
41-mp-service-before)
  step 41-mp-service-before
  M=mini-project
  c "3) CHECK THE SERVICE: users report the app is unreachable"
  r "$K run client --image=busybox:1.36 --restart=Never -i --rm -- wget -qO- -T 3 http://troubleshooting-service 2>/dev/null; echo exit=\$?"
  r "$K describe service troubleshooting-service | grep -E 'Selector|TargetPort|Endpoints'"
  c "4) CHECK ENDPOINTS"
  r $K get endpoints troubleshooting-service
  c "ROOT CAUSE: compare the Pod labels with the Service selector"
  r $K get pods --show-labels
  r "$K get service troubleshooting-service -o jsonpath='{.spec.selector}{\"\\n\"}'"
  ;;
42-mp-service-after)
  step 42-mp-service-after
  M=mini-project
  r "diff -bB $M/service.yaml $M/service-fixed.yaml"
  r $K apply -f $M/service-fixed.yaml
  r $K get endpoints troubleshooting-service
  r "$K describe service troubleshooting-service | grep -E 'Selector|TargetPort|Endpoints'"
  r "$K run client --image=busybox:1.36 --restart=Never -i --rm -- wget -qO- -T 3 http://troubleshooting-service 2>/dev/null | grep title"
  ;;
43-mp-pod-before)
  step 43-mp-pod-before
  M=mini-project
  c "5) CREATE THE BROKEN POD"
  r $K apply -f $M/broken-pod.yaml
  sleep 25
  c "6) TROUBLESHOOT IT (no YAML changes yet)"
  r $K get pod project-broken-pod
  r "$K describe pod project-broken-pod | sed -n '/Containers:/,/Ready:/p;/Events/,\$p'"
  ;;
44-mp-pod-after)
  step 44-mp-pod-after
  M=mini-project
  r "diff -bB $M/broken-pod.yaml $M/fixed-pod.yaml"
  r $K delete pod project-broken-pod --now
  r $K apply -f $M/fixed-pod.yaml
  r $K wait --for=condition=Ready pod/project-broken-pod --timeout=60s
  r $K get pod project-broken-pod
  ;;
45-mp-final)
  step 45-mp-final
  M=mini-project
  c "final state: Service -> 2 Pods (the fixed standalone pod has no app label, so it is not an endpoint)"
  r $K get pods -o wide --show-labels
  r $K get service,endpoints troubleshooting-service
  r "$K events --types=Warning | tail -5"
  r $K delete -f $M/fixed-pod.yaml -f $M/service-fixed.yaml -f $M/deployment.yaml --now
  ;;
*) echo "unknown step $1" >&2; exit 1;;
esac
