#!/bin/bash
# Lab script for Session 13 (Storage, HPA, Probes). Usage: bash lab/run.sh <step>
# Each step writes its transcript to lab/<step>.txt
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
V=01-kubernetes-volumes
case "$1" in
00-cluster)
  step 00-cluster
  r minikube -p k8s-b status
  r $K get nodes -o wide
  r "minikube -p k8s-b addons list | grep -E 'metrics-server|storage-provisioner|default-storageclass'"
  r $K get pods -n kube-system
  ;;
01-emptydir)
  step 01-emptydir
  r $K apply -f $V/emptydir-pod.yaml
  r $K wait --for=condition=Ready pod/emptydir-demo --timeout=180s
  r "$K exec emptydir-demo -- sh -c 'echo \"written at \$(date +%T) by Ajij\" > /data/note.txt; ls -l /data; cat /data/note.txt'"
  c "1) crash the container (stop nginx = PID 1). Same Pod, new container."
  r $K exec emptydir-demo -- nginx -s stop
  sleep 8
  r $K get pod emptydir-demo
  r $K exec emptydir-demo -- cat /data/note.txt
  c "2) delete the whole Pod and create it again"
  r $K delete pod emptydir-demo
  r $K apply -f $V/emptydir-pod.yaml
  r $K wait --for=condition=Ready pod/emptydir-demo --timeout=120s
  r $K exec emptydir-demo -- ls -la /data
  r $K exec emptydir-demo -- cat /data/note.txt
  r $K delete pod emptydir-demo
  ;;
02-hostpath)
  step 02-hostpath
  r $K apply -f $V/hostpath-pod.yaml
  r $K wait --for=condition=Ready pod/hostpath-demo --timeout=120s
  r "$K exec hostpath-demo -- sh -c 'echo \"hostPath data from Ajij\" > /data/host.txt; cat /data/host.txt'"
  c "the file really lives on the node's disk:"
  r minikube -p k8s-b ssh -- ls -l /tmp/hostpath-data
  r $K delete pod hostpath-demo
  r $K apply -f $V/hostpath-pod.yaml
  r $K wait --for=condition=Ready pod/hostpath-demo --timeout=120s
  r $K exec hostpath-demo -- cat /data/host.txt
  r $K get pod hostpath-demo -o wide
  r $K delete pod hostpath-demo
  ;;
03-pv-pvc-asis)
  step 03-pv-pvc-asis
  r $K apply -f $V/pv.yaml
  r $K get pv student-pv
  r $K apply -f $V/pvc.yaml
  sleep 5
  r $K get pvc student-pvc
  r $K get pv
  r "$K get pvc student-pvc -o jsonpath='{.spec.storageClassName}{\"\\n\"}'"
  r "$K get pv student-pv -o jsonpath='storageClassName=[{.spec.storageClassName}]{\"\\n\"}'"
  ;;
04-pv-pvc-static)
  step 04-pv-pvc-static
  r $K delete pvc student-pvc
  r $K get pv
  r cat $V/pvc-static.yaml
  r $K apply -f $V/pvc-static.yaml
  sleep 3
  r $K get pvc student-pvc
  r $K get pv student-pv
  r $K apply -f $V/pv-pod.yaml
  r $K wait --for=condition=Ready pod/storage-demo --timeout=120s
  r "$K exec storage-demo -- sh -c 'echo \"PV data from Ajij\" > /data/pv.txt; cat /data/pv.txt'"
  c "delete the Pod: the PVC and PV stay, so the data stays"
  r $K delete pod storage-demo
  r $K apply -f $V/pv-pod.yaml
  r $K wait --for=condition=Ready pod/storage-demo --timeout=120s
  r $K exec storage-demo -- cat /data/pv.txt
  c "delete Pod + PVC: reclaimPolicy Retain keeps the PV (Released) and its data"
  r $K delete pod storage-demo
  r $K delete pvc student-pvc
  r $K get pv student-pv
  r minikube -p k8s-b ssh -- cat /tmp/student-data/pv.txt
  r $K delete pv student-pv
  ;;
05-dynamic)
  step 05-dynamic
  r $K get storageclass
  r $K describe storageclass standard
  r $K apply -f $V/dynamic-pvc.yaml
  sleep 4
  r $K get pvc dynamic-pvc
  r $K get pv
  r $K apply -f $V/dynamic-pod.yaml
  r $K wait --for=condition=Ready pod/dynamic-demo --timeout=120s
  r "$K exec dynamic-demo -- sh -c 'echo \"dynamically provisioned\" > /data/dyn.txt; cat /data/dyn.txt'"
  r $K delete pod dynamic-demo
  r $K apply -f $V/dynamic-pod.yaml
  r $K wait --for=condition=Ready pod/dynamic-demo --timeout=120s
  r $K exec dynamic-demo -- cat /data/dyn.txt
  c "delete the PVC: reclaimPolicy Delete removes the PV automatically"
  r $K delete pod dynamic-demo
  r $K delete pvc dynamic-pvc
  sleep 5
  r $K get pv
  ;;
06-storageclass)
  step 06-storageclass
  r $K apply -f $V/storageclass.yaml
  r $K get storageclass
  r $K apply -f $V/sc-pvc.yaml
  sleep 4
  r $K get pvc fast-pvc
  r "$K describe pvc fast-pvc | sed -n '/Events/,\$p'"
  r $K apply -f $V/sc-pod.yaml
  r $K wait --for=condition=Ready pod/fast-demo --timeout=120s
  r $K get pvc fast-pvc
  r "$K get pv -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.name,SC:.spec.storageClassName,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase"
  r $K delete pod fast-demo
  r $K delete pvc fast-pvc
  r $K delete storageclass ajij-fast
  ;;
06b-storageclass-debug)
  step 06b-storageclass-debug
  c "re-create the WaitForFirstConsumer class and investigate why the claim never bound"
  r $K apply -f $V/storageclass.yaml -f $V/sc-pvc.yaml -f $V/sc-pod.yaml
  sleep 30
  r $K get pod fast-demo
  r $K get pvc fast-pvc
  r "$K describe pvc fast-pvc | sed -n '/Events/,\$p' | cut -c1-260"
  r "$K logs -n kube-system storage-provisioner --tail=40 | grep -E '^E' | tail -2"
  r $K auth can-i get nodes --as=system:serviceaccount:kube-system:storage-provisioner
  ;;
06c-storageclass-fix)
  step 06c-storageclass-fix
  c "FIX: allow the provisioner's ServiceAccount to read Nodes"
  r $K apply -f $V/provisioner-nodes-rbac.yaml
  r $K auth can-i get nodes --as=system:serviceaccount:kube-system:storage-provisioner
  r $K wait --for=condition=Ready pod/fast-demo --timeout=120s
  r $K get pvc fast-pvc
  r "$K get pv -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.name,SC:.spec.storageClassName,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase"
  r "$K exec fast-demo -- sh -c 'echo on-demand > /data/x.txt; cat /data/x.txt'"
  r $K delete pod fast-demo
  r $K delete pvc fast-pvc
  r $K delete storageclass ajij-fast
  ;;
10-hpa-deploy)
  step 10-hpa-deploy
  r cat 02-hpa/deployment.yaml
  r $K apply -f 02-hpa/deployment.yaml -f 02-hpa/service.yaml
  r $K rollout status deployment/hpa-demo --timeout=180s
  r $K get deploy,pods,svc -l app=hpa-demo
  r $K get svc hpa-demo-service
  r $K top pods
  ;;
11-hpa-configure)
  step 11-hpa-configure
  r cat 02-hpa/hpa.yml
  r $K apply -f 02-hpa/hpa.yml
  r $K get hpa
  c "wait ~30s for the first metrics scrape"
  sleep 30
  r $K get hpa
  r $K top pods -l app=hpa-demo
  r $K describe hpa hpa-demo
  ;;
12-hpa-watch)
  # started in the background before 12-hpa-load and stopped after 14-hpa-scaledown
  ( echo "\$ $K get hpa hpa-demo -w     ### each line prefixed with the time it arrived"
    $K get hpa hpa-demo -w 2>&1 | while IFS= read -r l; do echo "[$(date +%H:%M:%S)] $l"; done ) > "$LAB/12-hpa-watch.txt"
  ;;
12-hpa-load)
  step 12-hpa-load
  r cat 02-hpa/load-generator.yaml
  r $K apply -f 02-hpa/load-generator.yaml
  r $K wait --for=condition=Ready pod/load-generator --timeout=120s
  r $K logs load-generator
  for i in $(seq 1 ${2:-10}); do
    sleep 30
    ts "snapshot $i"
    r $K get hpa hpa-demo
    r $K top pods -l app=hpa-demo
    r $K get pods -l app=hpa-demo
  done
  ;;
12b-hpa-more-load)
  step 12b-hpa-more-load
  c "increase the load: two more generators (same YAML, different names)"
  r "sed 's/name: load-generator\$/name: load-generator-2/' 02-hpa/load-generator.yaml | $K apply -f -"
  r "sed 's/name: load-generator\$/name: load-generator-3/' 02-hpa/load-generator.yaml | $K apply -f -"
  for i in $(seq 1 ${2:-8}); do
    sleep 30
    ts "snapshot $i"
    r $K get hpa hpa-demo
    r $K top pods
  done
  r $K get pods -l app=hpa-demo -o wide
  ;;
13-hpa-describe)
  step 13-hpa-describe
  r $K describe hpa hpa-demo
  r $K get deploy hpa-demo
  ;;
14-hpa-scaledown)
  step 14-hpa-scaledown
  ts "stopping the load"
  r $K delete pod load-generator load-generator-2 load-generator-3
  for i in $(seq 1 ${2:-9}); do
    sleep 60
    ts "snapshot $i (after stop)"
    r $K get hpa hpa-demo
    r $K get pods -l app=hpa-demo
  done
  r "$K describe hpa hpa-demo | sed -n '/Events/,\$p'"
  ;;
15-hpa-cleanup)
  step 15-hpa-cleanup
  r $K delete -f 02-hpa/hpa.yml -f 02-hpa/service.yaml -f 02-hpa/deployment.yaml
  ;;
20-liveness)
  step 20-liveness
  r "grep -A6 livenessProbe 03-probes/liveness.yaml"
  r $K apply -f 03-probes/liveness.yaml
  for i in 1 2 3; do sleep 25; ts "check $i"; r $K get pod liveness-demo; done
  r "$K describe pod liveness-demo | sed -n '/Events/,\$p'"
  c "FIX: point the probe at a path nginx really serves (/). Probes of a bare Pod are immutable, so recreate it."
  r $K delete pod liveness-demo --now
  r "grep -A3 httpGet 03-probes/liveness-fixed.yaml"
  r $K apply -f 03-probes/liveness-fixed.yaml
  sleep 45
  r $K get pod liveness-demo
  r "$K describe pod liveness-demo | sed -n '/Events/,\$p'"
  r $K delete pod liveness-demo --now
  ;;
21-readiness)
  step 21-readiness
  r "grep -A5 readinessProbe 03-probes/readiness.yaml"
  r $K apply -f 03-probes/readiness.yaml
  r $K expose pod readiness-demo --port=80 --name=readiness-svc
  sleep 25
  r $K get pod readiness-demo
  r $K get endpoints readiness-svc
  r "$K describe pod readiness-demo | sed -n '/Events/,\$p'"
  c "RECOVER without restarting: create the page the probe is asking for"
  r "$K exec readiness-demo -- sh -c 'echo ready > /usr/share/nginx/html/wrong-path'"
  sleep 8
  r $K get pod readiness-demo
  r $K get endpoints readiness-svc
  c "BREAK again: remove the page -> pod leaves the Service, but is NOT restarted"
  r $K exec readiness-demo -- rm /usr/share/nginx/html/wrong-path
  sleep 20
  r $K get pod readiness-demo
  r $K get endpoints readiness-svc
  r $K delete svc readiness-svc
  r $K delete pod readiness-demo --now
  ;;
22-startup)
  step 22-startup
  c "a) instructor's startup.yaml: nginx starts fast, startup probe passes at once"
  r $K apply -f 03-probes/startup.yaml
  r $K wait --for=condition=Ready pod/startup-demo --timeout=60s
  r $K get pod startup-demo
  r $K delete pod startup-demo --now
  c "b) slow app (20 s warm-up) with only 6 s of startup budget"
  r "grep -A6 ' startupProbe:' 03-probes/startup-slow-broken.yaml"
  r $K apply -f 03-probes/startup-slow-broken.yaml
  for i in 1 2 3; do sleep 20; ts "check $i"; r $K get pod slow-start; done
  r "$K describe pod slow-start | sed -n '/Events/,\$p'"
  r $K delete pod slow-start --now
  c "c) FIX: failureThreshold 30 (60 s budget)"
  r "grep -A6 ' startupProbe:' 03-probes/startup-slow-fixed.yaml"
  r $K apply -f 03-probes/startup-slow-fixed.yaml
  sleep 10
  ts "10s"; r $K get pod slow-start
  sleep 20
  ts "30s"; r $K get pod slow-start
  r "$K describe pod slow-start | sed -n '/Events/,\$p'"
  r $K delete pod slow-start --now
  ;;
30-mini-deploy)
  step 30-mini-deploy
  M=mini-project; N="-n production-webapp"
  r $K apply -f $M/namespace.yaml
  r $K apply -f $M/pvc.yaml
  r $K get pvc $N
  r $K apply -f $M/deployment.yaml -f $M/service.yaml
  r $K rollout status deployment/web-app $N --timeout=180s
  r $K apply -f $M/hpa.yaml
  sleep 40
  r $K get all,pvc $N
  ;;
31-mini-storage)
  step 31-mini-storage
  N="-n production-webapp"
  r "POD_NAME=\$($K get pods $N -l app=web-app -o jsonpath='{.items[0].metadata.name}'); echo \$POD_NAME"
  r "$K exec $N \$POD_NAME -- sh -c 'echo \"Student: Ajij Uttam (24bcs10103)\" > /data/student.txt'"
  r $K exec $N \$POD_NAME -- cat /data/student.txt
  r $K delete pod $N \$POD_NAME
  r $K rollout status deployment/web-app $N --timeout=120s
  r $K get pods $N
  r "NEW_POD=\$($K get pods $N -l app=web-app -o jsonpath='{.items[0].metadata.name}'); echo \$NEW_POD"
  r $K exec $N \$NEW_POD -- cat /data/student.txt
  c "both replicas mount the same PVC, so the other Pod sees the file too:"
  r "for p in \$($K get pods $N -l app=web-app -o name); do echo \"\$p: \$($K exec $N \$p -- cat /data/student.txt)\"; done"
  ;;
32-mini-service)
  step 32-mini-service
  N="-n production-webapp"
  r $K get svc,endpoints $N
  r "$K port-forward $N svc/web-service 8080:80 > /dev/null 2>&1 & PF=\$!; sleep 3"
  r "curl -s http://localhost:8080 | head -8"
  r "curl -s -o /dev/null -w 'HTTP %{http_code}\n' http://localhost:8080"
  r kill \$PF
  ;;
33-mini-hpa)
  step 33-mini-hpa
  N="-n production-webapp"
  r $K run load-generator $N --image=busybox:1.36 --restart=Never -- /bin/sh -c "'while true; do wget -q -O- http://web-service > /dev/null; done'"
  for i in $(seq 1 ${2:-8}); do
    sleep 30
    ts "snapshot $i"
    r $K get hpa $N
    r $K top pods $N -l app=web-app
  done
  r $K get pods $N
  r $K delete pod load-generator $N
  ;;
33b-mini-hpa-30)
  step 33b-mini-hpa-30
  N="-n production-webapp"
  c "Bonus challenge 1: one load generator only reached ~40% (below 50%), so lower the target to 30%"
  r $K patch hpa web-app-hpa $N --type=json -p "'[{\"op\":\"replace\",\"path\":\"/spec/metrics/0/resource/target/averageUtilization\",\"value\":30}]'"
  r $K run load-generator $N --image=busybox:1.36 --restart=Never -- /bin/sh -c "'while true; do wget -q -O- http://web-service > /dev/null; done'"
  for i in $(seq 1 ${2:-6}); do
    sleep 30
    ts "snapshot $i"
    r $K get hpa $N
    r $K top pods $N -l app=web-app
  done
  r $K get pods $N -o wide
  r "$K describe hpa web-app-hpa $N | sed -n '/Events/,\$p'"
  r $K delete pod load-generator $N
  r $K apply -f mini-project/hpa.yaml
  ;;
34-mini-selfheal)
  step 34-mini-selfheal
  N="-n production-webapp"
  r $K get pods $N -l app=web-app
  r "P=\$($K get pods $N -l app=web-app -o jsonpath='{.items[0].metadata.name}'); echo \$P"
  r $K get endpoints web-service $N
  c "simulate an app fault: delete nginx's index page inside ONE pod, so GET / returns 403"
  r $K exec $N \$P -- rm /usr/share/nginx/html/index.html
  r "$K exec $N \$P -- curl -s -o /dev/null -w '%{http_code}\n' http://localhost/"
  c "poll every 3 s: pod READY/RESTARTS and the Service endpoints"
  for i in $(seq 1 16); do
    echo "[$(date +%H:%M:%S)] $($K get pod $N $P --no-headers -o custom-columns=POD:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount) | endpoints: $($K get endpoints web-service $N -o jsonpath='{.subsets[*].addresses[*].ip}')"
    sleep 3
  done
  r $K get pods $N -l app=web-app
  r "$K describe pod $N \$P | sed -n '/Events/,\$p'"
  ;;
35-mini-readiness-gate)
  step 35-mini-readiness-gate
  N="-n production-webapp"
  c "Bonus challenge 2: readinessProbe path -> /does-not-exist"
  r $K patch deployment web-app $N --type=json -p "'[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"/does-not-exist\"}]'"
  sleep 45
  r $K get pods $N -l app=web-app
  r $K get endpoints web-service $N
  r "P=\$($K get pods $N -l app=web-app -o jsonpath='{.items[0].metadata.name}'); $K describe pod $N \$P | sed -n '/Events/,\$p' | tail -4"
  c "revert: path back to /"
  r $K patch deployment web-app $N --type=json -p "'[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/readinessProbe/httpGet/path\",\"value\":\"/\"}]'"
  r $K rollout status deployment/web-app $N --timeout=120s
  r $K get pods $N -l app=web-app
  r $K get endpoints web-service $N
  ;;
36-mini-liveness-loop)
  step 36-mini-liveness-loop
  N="-n production-webapp"
  c "Bonus challenge 3: livenessProbe path -> /crash"
  r $K patch deployment web-app $N --type=json -p "'[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/livenessProbe/httpGet/path\",\"value\":\"/crash\"}]'"
  for i in 1 2 3 4; do sleep 20; ts "check $i"; r $K get pods $N -l app=web-app; done
  r "P=\$($K get pods $N -l app=web-app -o jsonpath='{.items[0].metadata.name}'); $K describe pod $N \$P | sed -n '/Events/,\$p' | tail -6"
  c "revert: path back to /"
  r $K patch deployment web-app $N --type=json -p "'[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/livenessProbe/httpGet/path\",\"value\":\"/\"}]'"
  r $K rollout status deployment/web-app $N --timeout=120s
  sleep 30
  r $K get pods $N -l app=web-app
  ;;
37-mini-final)
  step 37-mini-final
  N="-n production-webapp"
  r $K get all,pvc $N
  r $K exec $N deploy/web-app -- cat /data/student.txt
  r $K delete namespace production-webapp
  ;;
*) echo "unknown step $1" >&2; exit 1;;
esac
