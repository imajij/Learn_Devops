#!/usr/bin/env bash
# Build the instrumented app image and deploy it with its ServiceMonitor + PrometheusRule.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 02-deploy-app
c "first try: minikube -p obs image build hit Docker Hub 429 Too Many Requests, so build with the host Docker (base image cached) and load it"
r "docker build -q -t shop-app:1.0 app/"
r "minikube -p obs image load --overwrite=true shop-app:1.0"
r "minikube -p obs image ls | grep shop-app"
r "kubectl --context obs apply -f manifests/monitoring/shop-app.yaml -f manifests/monitoring/alert-rules.yaml"
r "kubectl --context obs -n shop rollout status deploy/shop --timeout=120s"
r "kubectl --context obs -n shop rollout status deploy/payments --timeout=120s"
r "kubectl --context obs -n shop get pods,svc,servicemonitor,prometheusrule"
r "kubectl --context obs -n monitoring get pods"
