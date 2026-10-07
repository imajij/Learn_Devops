#!/bin/bash
# Session 11 Task 1: the 5 Service types. Usage: lab/services.sh <step> > lab/<step>.txt
source ~/devops-lab/k8s-a/common.sh
cd "$(dirname "$0")/../services"
X='kubectl exec curl --'      # HTTP tests
D='kubectl exec dnsutils --'  # DNS tests
case $1 in
00-client)
  r kubectl apply -f client.yaml
  r kubectl wait --for=condition=Ready pod/dnsutils pod/curl --timeout=120s ;;
01-clusterip)
  r kubectl apply -f 01-clusterip/
  r kubectl rollout status deployment/web-clusterip --timeout=120s
  c "short pause: kube-proxy programs the new endpoints a moment after the pods turn Ready"
  r sleep 5
  r kubectl get svc web-clusterip -o wide
  r kubectl get pods -l app=web-clusterip -o wide
  r kubectl get endpointslices -l kubernetes.io/service-name=web-clusterip
  c 'connectivity from a pod: by DNS name, 30 requests -> which pod answered?'
  r "$X sh -c 'for i in \$(seq 1 30); do curl -s http://web-clusterip/hostname; echo; done' | sort | uniq -c"
  r "$X curl -s -m 3 http://\$(kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}')/hostname; echo"
  r "$D nslookup web-clusterip"
  c 'from the Mac (outside the cluster) the ClusterIP is not reachable:'
  r "curl -s -m 3 http://\$(kubectl get svc web-clusterip -o jsonpath='{.spec.clusterIP}')/hostname || echo \"curl exit \$? -> no route from outside the cluster\"" ;;
02-nodeport)
  r kubectl apply -f 02-nodeport/
  r kubectl rollout status deployment/web-nodeport --timeout=120s
  r sleep 5
  r kubectl get svc web-nodeport -o wide
  r 'kubectl get nodes -o wide | awk "{print \$1, \$6}"'
  c 'from the node itself and from a pod, via <NodeIP>:30080'
  r 'minikube -p k8s-a ssh -- curl -s http://192.168.49.2:30080/hostname; echo'
  r "$X curl -s http://192.168.49.2:30080/hostname; echo"
  c 'from the Mac: the Docker-driver node IP is not routable, so ask minikube for a tunnelled URL'
  r 'curl -s -m 3 http://192.168.49.2:30080/hostname || echo "curl exit $? (node IP not reachable from macOS)"'
  r '(minikube -p k8s-a service web-nodeport --url > ~/devops-lab/k8s-a/np-url.txt 2>/dev/null &); until grep -q http ~/devops-lab/k8s-a/np-url.txt; do sleep 1; done; cat ~/devops-lab/k8s-a/np-url.txt'
  r 'for i in 1 2 3 4; do curl -s $(head -1 ~/devops-lab/k8s-a/np-url.txt)/hostname; echo; done'
  r 'pkill -f "minikube -p k8s-a service web-nodeport"; pkill -f "machines/k8s-a/id_rsa -L"; rm ~/devops-lab/k8s-a/np-url.txt' ;;
03-loadbalancer-pending)
  r kubectl apply -f 03-loadbalancer/
  r kubectl rollout status deployment/web-loadbalancer --timeout=120s
  r 'sleep 15; kubectl get svc web-loadbalancer'
  r "kubectl describe svc web-loadbalancer | grep -E 'Type|LoadBalancer Ingress|NodePort|Endpoints'" ;;
04-loadbalancer-tunnel)
  c 'start minikube tunnel in the background (it must keep running)'
  r '(minikube -p k8s-a tunnel > ~/devops-lab/k8s-a/tunnel.log 2>&1 &); sleep 1; echo tunnel started'
  r 'until kubectl get svc web-loadbalancer -o jsonpath="{.status.loadBalancer.ingress[0].ip}" | grep -q .; do sleep 1; done; kubectl get svc web-loadbalancer'
  r 'until grep -q web-loadbalancer ~/devops-lab/k8s-a/tunnel.log; do sleep 1; done; sleep 2; cat ~/devops-lab/k8s-a/tunnel.log'
  r 'for i in $(seq 1 9); do curl -s http://127.0.0.1:18080/hostname; echo; done | sort | uniq -c'
  r "kubectl get svc web-loadbalancer -o jsonpath='{.status.loadBalancer}'; echo"
  c "stop the tunnel: kill minikube tunnel and the ssh port-forward it started"
  r 'pkill -f "minikube -p k8s-a tunnel"; pkill -f "machines/k8s-a/id_rsa -L"; sleep 3; kubectl get svc web-loadbalancer'
  r 'curl -s -m 3 http://127.0.0.1:18080/hostname || echo "curl exit $? -> tunnel stopped, nothing listening on 127.0.0.1:18080"' ;;
05-externalname)
  r kubectl apply -f 04-externalname/service.yaml
  r kubectl get svc github-api -o wide
  r 'kubectl get endpointslices -l kubernetes.io/service-name=github-api'
  r "$D dig +noall +answer github-api.default.svc.cluster.local"
  r "$X curl -s -m 10 -o /dev/null -w 'http=%{http_code} ip=%{remote_ip}\n' https://github-api/zen"
  c 'TLS fails: the certificate is for api.github.com, not github-api. ExternalName is only a DNS alias.'
  r "$X curl -s -m 10 --resolve api.github.com:443:\$($D dig +short github-api.default.svc.cluster.local | tail -1) https://api.github.com/zen; echo" ;;
06-headless)
  r kubectl apply -f 05-headless/
  r kubectl rollout status statefulset/web --timeout=180s
  r kubectl get svc web-headless web-clusterip
  r kubectl get pods -l app=web-headless -o wide
  c 'normal ClusterIP service -> ONE A record (the virtual IP)'
  r "$D dig +noall +answer web-clusterip.default.svc.cluster.local"
  c 'headless service -> one A record PER POD (no virtual IP)'
  r "$D dig +noall +answer web-headless.default.svc.cluster.local"
  c 'every StatefulSet pod gets its own stable DNS name'
  r "$X sh -c 'for i in 0 1 2; do curl -s http://web-\$i.web-headless:8080/hostname; echo \" <- web-\$i.web-headless\"; done'"
  r "$D dig +noall +answer web-1.web-headless.default.svc.cluster.local" ;;
esac
