#!/bin/bash
# Kubernetes Fundamentals lab. Each section writes one transcript into lab/<name>.txt
# Cluster: minikube profile k8s-a (docker driver). KUBECONFIG points at a file that holds only this cluster.
source ~/devops-lab/k8s-a/common.sh
cd "$(dirname "$0")"
step=$1
case $step in
03-status)
  r minikube -p k8s-a status
  r kubectl cluster-info
  r kubectl get nodes -o wide
  r kubectl version
  r minikube -p k8s-a ip ;;
03b-status-ready)
  c 'Right after "minikube start" the node was NotReady (CNI still starting). Waiting for Ready:'
  r kubectl wait --for=condition=Ready node/k8s-a --timeout=180s
  r kubectl get nodes -o wide
  r "kubectl describe node k8s-a | grep -E 'Ready|cpu:|memory:|Container Runtime|Kubelet Version|PodCIDR:'" ;;
04-control-plane)
  r kubectl get pods -n kube-system -o wide
  r 'minikube -p k8s-a ssh -- sudo ls /etc/kubernetes/manifests'
  r "kubectl get --raw='/readyz?verbose' | tail -6" ;;
05-node-components)
  r 'minikube -p k8s-a ssh -- systemctl is-active kubelet containerd'
  r "minikube -p k8s-a ssh -- sudo crictl ps -o json | jq -r '.containers[] | [.metadata.name, .state, .labels[\"io.kubernetes.pod.name\"]] | @tsv' | column -t"
  r 'kubectl get daemonset -n kube-system'
  r "kubectl describe node k8s-a | sed -n '/^Conditions:/,/^Addresses:/p'" ;;
06-objects)
  r 'kubectl api-resources --namespaced=true | head -20'
  r kubectl get namespaces
  r kubectl run hello-pod --image=nginx:1.27 --labels=app=hello
  r kubectl wait --for=condition=Ready pod/hello-pod --timeout=120s
  r kubectl get pods -o wide --show-labels
  r "kubectl describe pod hello-pod | sed -n '/^Events:/,\$p'"
  r 'kubectl exec hello-pod -- nginx -v'
  r 'kubectl logs hello-pod | tail -3'
  r 'kubectl explain pod.spec.containers.image | head -12'
  r kubectl delete pod hello-pod ;;
07-create-deployment)
  r kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1
  r kubectl rollout status deployment/kubernetes-bootcamp --timeout=180s
  r kubectl get deployments
  r kubectl get replicasets
  r kubectl get pods -o wide
  r 'POD=$(kubectl get pods -l app=kubernetes-bootcamp -o jsonpath="{.items[0].metadata.name}"); echo POD=$POD'
  c 'The bootcamp image is amd64-only; on this arm64 node it runs under qemu emulation and takes a few seconds to start listening'
  r 'until kubectl logs $POD | grep -q Started; do sleep 2; done; kubectl logs $POD'
  r 'kubectl exec $POD -- uname -m'
  r 'kubectl exec $POD -- curl -s localhost:8080' ;;
08-expose)
  r 'kubectl run client --image=curlimages/curl:8.10.1 -- sleep 3600; kubectl wait --for=condition=Ready pod/client --timeout=90s'
  r kubectl expose deployment/kubernetes-bootcamp --type=NodePort --port 8080
  r kubectl get services
  r kubectl describe service kubernetes-bootcamp
  r 'kubectl get endpointslices -l kubernetes.io/service-name=kubernetes-bootcamp'
  c 'Docker driver on macOS: the node IP 192.168.49.2 is not reachable from the Mac, so "minikube service --url" opens a tunnel and must stay running'
  r '(minikube -p k8s-a service kubernetes-bootcamp --url > ~/devops-lab/k8s-a/url.txt 2>/dev/null &) ; until grep -q http ~/devops-lab/k8s-a/url.txt; do sleep 1; done; URL=$(head -1 ~/devops-lab/k8s-a/url.txt); echo $URL'
  r 'curl -s $URL'
  r 'curl -s --max-time 3 http://$(minikube -p k8s-a ip):$(kubectl get svc kubernetes-bootcamp -o jsonpath={.spec.ports[0].nodePort}) || echo "direct NodePort from macOS: timed out (exit $?)"'
  r 'pkill -f "minikube -p k8s-a service kubernetes-bootcamp"; rm -f ~/devops-lab/k8s-a/url.txt'
  # note: this leaves the ssh port-forward child running; I killed it later with pkill -f "machines/k8s-a/id_rsa -L"
  r 'kubectl exec client -- curl -s http://kubernetes-bootcamp:8080' ;;
09-scale)
  c "Second run of steps 09-10 (the first run is in *-attempt1.txt). Recreate the deployment, Service and client pod from steps 07-08:"
  r kubectl create deployment kubernetes-bootcamp --image=gcr.io/google-samples/kubernetes-bootcamp:v1
  r kubectl expose deployment/kubernetes-bootcamp --type=NodePort --port 8080
  r "kubectl run client --image=curlimages/curl:8.10.1 -- sleep 3600; kubectl wait --for=condition=Ready pod/client --timeout=90s"
  r kubectl scale deployment/kubernetes-bootcamp --replicas=4
  r kubectl rollout status deployment/kubernetes-bootcamp --timeout=180s
  r kubectl get deployments
  r kubectl get pods -o wide
  c 'The bootcamp Deployment has no readinessProbe, so a pod is "Ready" before the emulated app listens. Wait for every pod to log "Started" first:'
  r 'for p in $(kubectl get pods -l app=kubernetes-bootcamp -o name); do until kubectl logs $p | grep -q Started; do sleep 2; done; done; echo all 4 apps listening'
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 20); do curl -s http://kubernetes-bootcamp:8080; done" | sort | uniq -c'
  r kubectl scale deployment/kubernetes-bootcamp --replicas=2
  r 'sleep 5; kubectl get pods' ;;
10-rolling-update)
  r kubectl set image deployment/kubernetes-bootcamp kubernetes-bootcamp=docker.io/jocatalin/kubernetes-bootcamp:v2
  r kubectl rollout status deployment/kubernetes-bootcamp --timeout=180s
  r kubectl get replicasets
  r 'kubectl wait --for=delete pod -l pod-template-hash=$(kubectl get rs -l app=kubernetes-bootcamp --sort-by=.metadata.creationTimestamp -o jsonpath="{.items[0].metadata.labels.pod-template-hash}") --timeout=120s'
  r 'for p in $(kubectl get pods -l app=kubernetes-bootcamp -o name); do until kubectl logs $p | grep -q Started; do sleep 2; done; done'
  r 'kubectl exec client -- sh -c "for i in \$(seq 1 6); do curl -s http://kubernetes-bootcamp:8080; done"'
  c 'Now a bad update: tag v10 does not exist'
  r kubectl set image deployment/kubernetes-bootcamp kubernetes-bootcamp=gcr.io/google-samples/kubernetes-bootcamp:v10
  r 'sleep 20; kubectl get pods'
  r "kubectl get events --field-selector reason=Failed -o custom-columns=MESSAGE:.message | head -3 | cut -c1-160"
  r kubectl rollout undo deployment/kubernetes-bootcamp
  r kubectl rollout status deployment/kubernetes-bootcamp --timeout=180s
  r kubectl rollout history deployment/kubernetes-bootcamp
  r 'kubectl describe deployment kubernetes-bootcamp | grep Image'
  r kubectl delete service/kubernetes-bootcamp deployment/kubernetes-bootcamp pod/client ;;
esac
