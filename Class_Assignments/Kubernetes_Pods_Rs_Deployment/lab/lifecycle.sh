#!/bin/bash
# Pod lifecycle lab (Session 10, Task 2). Usage: lab/lifecycle.sh <step> > lab/<step>.txt
# YAML files are in ../pod-lifecycle/ (the instructor's provided lifecycle files, unchanged).
source ~/devops-lab/k8s-a/common.sh
cd "$(dirname "$0")/../pod-lifecycle"
# busybox:1.36 was pre-loaded from mirror.gcr.io because of Docker Hub 429s, see lc-00-busybox-mirror.txt
# watch(): timestamped "kubectl get pod -w" for N seconds
W='while read l; do echo "$(date +%T) $l"; done'
state(){ r "kubectl get pod $1 -o jsonpath='phase={.status.phase}{\"\\n\"}state={.status.containerStatuses[*].state}{\"\\n\"}lastState={.status.containerStatuses[*].lastState}{\"\\n\"}'"; }
events(){ r "kubectl describe pod $1 | sed -n '/^Events:/,\$p' | cut -c1-170"; }
case $1 in
01-running)
  r kubectl apply -f 01-running.yaml
  r kubectl wait --for=condition=Ready pod/lifecycle-running --timeout=90s
  r kubectl get pod lifecycle-running -o wide
  state lifecycle-running
  r "kubectl describe pod lifecycle-running | sed -n '/^Conditions:/,/^Volumes:/p'"
  events lifecycle-running
  r kubectl delete pod lifecycle-running ;;
02-pending)
  r kubectl apply -f 02-pending.yaml
  r 'sleep 10; kubectl get pod lifecycle-pending -o wide'
  state lifecycle-pending
  r "kubectl describe pod lifecycle-pending | grep -A3 -E '^ +Requests:|^Conditions:'"
  events lifecycle-pending
  r kubectl delete pod lifecycle-pending ;;
03-succeeded)
  r kubectl apply -f 03-succeeded.yaml
  r "timeout 20 kubectl get pod lifecycle-succeeded -w | $W"
  r kubectl get pod lifecycle-succeeded
  state lifecycle-succeeded
  r kubectl logs lifecycle-succeeded
  events lifecycle-succeeded
  r kubectl delete pod lifecycle-succeeded ;;
04-failed)
  r kubectl apply -f 04-failed.yaml
  r "timeout 20 kubectl get pod lifecycle-failed -w | $W"
  r kubectl get pod lifecycle-failed
  state lifecycle-failed
  r kubectl logs lifecycle-failed
  r kubectl delete pod lifecycle-failed ;;
05-crashloopbackoff)
  r kubectl apply -f 05-crashloopbackoff.yaml
  r "timeout 75 kubectl get pod lifecycle-crashloop -w | $W"
  r kubectl get pod lifecycle-crashloop
  state lifecycle-crashloop
  r "kubectl logs lifecycle-crashloop; echo ---; kubectl logs lifecycle-crashloop --previous; echo"
  events lifecycle-crashloop
  r kubectl delete pod lifecycle-crashloop ;;
06-imagepullbackoff)
  r kubectl apply -f 06-imagepullbackoff.yaml
  r "timeout 30 kubectl get pod lifecycle-image-error -w | $W"
  state lifecycle-image-error
  events lifecycle-image-error
  r kubectl delete pod lifecycle-image-error
  # added after Docker Hub returned 429: same bad tag through the mirror shows the real NotFound
  r 'kubectl run bad-tag --image=mirror.gcr.io/library/nginx:this-tag-does-not-exist-99999'
  r 'sleep 15; kubectl get pod bad-tag'
  r "kubectl get pod bad-tag -o jsonpath='{.status.containerStatuses[0].state.waiting.message}' | cut -c1-200; echo"
  r kubectl delete pod bad-tag ;;
07-readiness)
  r kubectl apply -f 07-readiness.yaml
  r "timeout 20 kubectl get pod lifecycle-readiness -w | $W"
  r "kubectl describe pod lifecycle-readiness | grep -E 'Readiness:|^  (Ready|ContainersReady) '"
  r 'kubectl get pod lifecycle-readiness -o jsonpath="{range .status.conditions[*]}{.type}={.status} at {.lastTransitionTime}{\"\\n\"}{end}"'
  r kubectl delete pod lifecycle-readiness ;;
08-liveness)
  r kubectl apply -f 08-liveness.yaml
  r "timeout 75 kubectl get pod lifecycle-liveness -w | $W"
  r "kubectl describe pod lifecycle-liveness | grep -E 'Liveness:|Restart Count:|Last State|Reason:|Exit Code:'"
  r kubectl logs lifecycle-liveness --previous
  events lifecycle-liveness
  r kubectl delete pod lifecycle-liveness --grace-period=1 ;;
09-startup)
  r kubectl apply -f 09-startup.yaml
  r "timeout 50 kubectl get pod lifecycle-startup -w | $W"
  r "kubectl describe pod lifecycle-startup | grep -E 'Startup:|Restart Count:|^  (Ready|ContainersReady) '"
  r kubectl logs lifecycle-startup
  events lifecycle-startup
  r kubectl delete pod lifecycle-startup --grace-period=1 ;;
10-init-container)
  r kubectl apply -f 10-init-container.yaml
  r "timeout 25 kubectl get pod lifecycle-init -w | $W"
  r kubectl logs lifecycle-init -c setup
  r 'kubectl get pod lifecycle-init -o jsonpath="init: {.status.initContainerStatuses[0].state}{\"\\n\"}app:  {.status.containerStatuses[0].state}{\"\\n\"}"'
  events lifecycle-init
  r kubectl delete pod lifecycle-init ;;
11-multi-container)
  r kubectl apply -f 11-multi-container.yaml
  r kubectl wait --for=condition=Ready pod/lifecycle-multi-container --timeout=90s
  r kubectl get pod lifecycle-multi-container
  r 'kubectl get pod lifecycle-multi-container -o jsonpath="{range .status.containerStatuses[*]}{.name}: ready={.ready} state={.state}{\"\\n\"}{end}"'
  r 'sleep 12; kubectl logs lifecycle-multi-container -c sidecar'
  r 'kubectl exec lifecycle-multi-container -c sidecar -- wget -qO- http://localhost:80 | grep -o "<title>.*</title>"'
  r kubectl delete pod lifecycle-multi-container ;;
12-termination)
  r kubectl apply -f 12-termination.yaml
  r kubectl wait --for=condition=Ready pod/lifecycle-termination --timeout=90s
  r '(kubectl logs -f lifecycle-termination > ~/devops-lab/k8s-a/term.log 2>&1 &); sleep 2; echo following logs'
  r "(timeout 25 kubectl get pod lifecycle-termination -w | $W > ~/devops-lab/k8s-a/term-watch.log &); sleep 1; echo watching"
  r 'date +%T; time kubectl delete pod lifecycle-termination; date +%T'
  r 'sleep 3; cat ~/devops-lab/k8s-a/term-watch.log'
  r 'cat ~/devops-lab/k8s-a/term.log' ;;
esac
