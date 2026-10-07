#!/bin/bash
# Session 11 Tasks 3-4 (FQDN, CoreDNS) and the Task 2 live demo. Usage: lab/dns.sh <step> > lab/<step>.txt
# Needs the pods/services from services.sh (dnsutils, curl, web-clusterip, web-headless).
source ~/devops-lab/k8s-a/common.sh
cd "$(dirname "$0")/.."
D='kubectl exec dnsutils --'
case $1 in
10-fqdn-resolv)
  r "$D cat /etc/resolv.conf"
  c 'the same Service, from short name to full FQDN'
  r "$D nslookup web-clusterip"
  r "$D nslookup web-clusterip.default"
  r "$D nslookup web-clusterip.default.svc"
  r "$D nslookup web-clusterip.default.svc.cluster.local." ;;
11-fqdn-namespaces)
  r kubectl create namespace team-b
  r 'kubectl -n team-b create deployment api --image=registry.k8s.io/e2e-test-images/agnhost:2.53 -- /agnhost netexec --http-port=8080'
  r 'kubectl -n team-b expose deployment api --port=80 --target-port=8080'
  r 'kubectl -n team-b rollout status deployment/api --timeout=120s; sleep 3'
  c 'from a pod in namespace "default":'
  r "$D nslookup api"
  r "$D nslookup api.team-b"
  r "$D dig +short api.team-b.svc.cluster.local"
  r "kubectl exec curl -- curl -s http://api.team-b/hostname; echo"
  r "kubectl exec curl -- curl -s -m 3 http://api/hostname || echo \"curl exit \$? (could not resolve host 'api' from namespace default)\"" ;;
12-fqdn-records)
  c 'SRV record: named port "http" over TCP -> port number + target name'
  r "$D dig +noall +answer SRV _http._tcp.web-clusterip.default.svc.cluster.local"
  r "$D dig +noall +answer SRV _http._tcp.web-headless.default.svc.cluster.local"
  c 'pod A record: <pod-ip-with-dashes>.<namespace>.pod.cluster.local'
  r 'IP=$(kubectl get pod curl -o jsonpath="{.status.podIP}"); echo $IP'
  r "$D dig +noall +answer \$(echo \$IP | tr . -).default.pod.cluster.local"
  c 'reverse lookup of a Service IP and the kubernetes API service'
  r "$D dig +noall +answer -x \$(kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}')"
  r "$D dig +noall +answer kubernetes.default.svc.cluster.local"
  r "$D nslookup google.com | tail -4" ;;
20-coredns-objects)
  r 'kubectl -n kube-system get deployment,pods,svc -l k8s-app=kube-dns -o wide'
  r 'kubectl -n kube-system get endpointslices -l kubernetes.io/service-name=kube-dns'
  r "kubectl -n kube-system get deployment coredns -o jsonpath='{.spec.template.spec.containers[0].image}{\"\\n\"}{.spec.template.spec.containers[0].args}{\"\\n\"}'"
  r 'kubectl -n kube-system logs deployment/coredns | head -8' ;;
21-coredns-corefile)
  r "kubectl -n kube-system get configmap coredns -o jsonpath='{.data.Corefile}'" ;;
22-coredns-querylog)
  c 'minikube already enables the "log" plugin (first line of the Corefile), so every query is logged'
  r "$D nslookup web-clusterip >/dev/null; $D nslookup api.team-b >/dev/null; $D nslookup github.com >/dev/null; sleep 2; echo queries sent from \$(kubectl get pod dnsutils -o jsonpath='{.status.podIP}')"
  r "kubectl -n kube-system logs deployment/coredns --since=20s | grep \$(kubectl get pod dnsutils -o jsonpath='{.status.podIP}') | grep -E ' \"A IN ' | sed -E 's/^.*\"A IN ([^ ]+) .*\" ([A-Z]+) .*$/A \\1 -> \\2/'" ;;
23-dns-broken)
  c 'Troubleshooting demo. Break DNS: scale CoreDNS to 0 (simulates crashed/evicted DNS pods)'
  r 'kubectl -n kube-system scale deployment coredns --replicas=0'
  r 'kubectl -n kube-system wait --for=delete pod -l k8s-app=kube-dns --timeout=60s'
  c 'symptom seen by an application:'
  r "kubectl exec curl -- curl -s -m 8 http://web-clusterip/hostname || echo \"curl exit \$?\""
  c 'step 1: is it DNS or the network? -> same request by IP works'
  r "kubectl exec curl -- curl -s http://\$(kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}')/hostname; echo"
  c 'step 2: query DNS directly'
  r "$D nslookup -timeout=3 web-clusterip"
  r "$D cat /etc/resolv.conf | grep nameserver"
  c 'step 3: does the DNS Service have endpoints? are the DNS pods running?'
  r 'kubectl -n kube-system get svc kube-dns'
  r 'kubectl -n kube-system get endpointslices -l kubernetes.io/service-name=kube-dns'
  r 'kubectl -n kube-system get pods -l k8s-app=kube-dns'
  r 'kubectl -n kube-system get deployment coredns' ;;
24-dns-fixed)
  c 'root cause: coredns Deployment at 0 replicas -> kube-dns Service has no endpoints. Fix:'
  r 'kubectl -n kube-system scale deployment coredns --replicas=1'
  r 'kubectl -n kube-system rollout status deployment coredns --timeout=120s'
  r 'kubectl -n kube-system get endpointslices -l kubernetes.io/service-name=kube-dns'
  r "$D nslookup web-clusterip"
  r "kubectl exec curl -- curl -s http://web-clusterip/hostname; echo"
  ;;
30-compare-deploy-rs)
  r 'kubectl create deployment demo --image=registry.k8s.io/e2e-test-images/agnhost:2.53 --replicas=3 -- /agnhost netexec --http-port=8080'
  r 'kubectl rollout status deployment/demo --timeout=120s'
  r 'kubectl get deploy,rs,pods -l app=demo'
  c 'ownership chain: Pod -> ReplicaSet -> Deployment'
  r "kubectl get pods -l app=demo -o jsonpath='{range .items[*]}{.metadata.name} owner={.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{\"\\n\"}{end}'"
  r "kubectl get rs -l app=demo -o jsonpath='{range .items[*]}{.metadata.name} owner={.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}{\"\\n\"}{end}'"
  c 'ReplicaSet self-healing: delete a pod, a new one appears'
  r 'kubectl delete pod $(kubectl get pods -l app=demo -o name | head -1 | cut -d/ -f2) --wait=false'
  r 'sleep 3; kubectl get pods -l app=demo'
  c 'editing the ReplicaSet directly does not survive: the Deployment owns it'
  r 'kubectl scale rs $(kubectl get rs -l app=demo -o name | cut -d/ -f2) --replicas=5; sleep 3; kubectl get rs -l app=demo'
  c 'a rolling update = the Deployment creates a NEW ReplicaSet'
  r 'kubectl set env deployment/demo VERSION=2; kubectl rollout status deployment/demo --timeout=120s; kubectl get rs -l app=demo'
  r kubectl delete deployment demo ;;
31-compare-ds-sts)
  r 'kubectl get daemonsets -A'
  r 'kubectl -n kube-system get pods -l k8s-app=kube-proxy -o wide'
  c 'StatefulSet: ordered names, stable identity; delete web-1 -> comes back as web-1 (new IP, same DNS name)'
  r 'kubectl get pods -l app=web-headless -o wide | awk "{print \$1, \$3, \$6}"'
  r 'kubectl delete pod web-1'
  r 'kubectl wait --for=condition=Ready pod/web-1 --timeout=60s; kubectl get pods -l app=web-headless -o wide | awk "{print \$1, \$3, \$6}"'
  r "sleep 2; $D dig +noall +answer web-1.web-headless.default.svc.cluster.local" ;;
32-compare-rs-svc)
  c 'ReplicaSet keeps pods alive; Service gives them one address. Pod IPs change, the Service IP does not:'
  r "kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}{\"\\n\"}'"
  r 'kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip'
  r 'kubectl rollout restart deployment/web-clusterip; kubectl rollout status deployment/web-clusterip --timeout=120s'
  r 'sleep 3; kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip'
  r "kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}{\"\\n\"}'"
  c 'how traffic reaches the pods: kube-proxy iptables rules for this Service IP'
  r "minikube -p k8s-a ssh -- sudo iptables -t nat -S | grep 'default/web-clusterip' | grep -E 'KUBE-SVC|probability|DNAT' | grep -v '! -s' | sed -E 's/ -m comment --comment \"[^\"]*\"//; s/ -p tcp -m tcp//'" ;;
esac
