#!/usr/bin/env bash
# Install kube-prometheus-stack (Prometheus Operator, Prometheus, Alertmanager, Grafana,
# kube-state-metrics, node-exporter) with small resource requests, then build + deploy the app.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 01-install-monitoring
r "helm upgrade --install kps prometheus-community/kube-prometheus-stack --version 92.1.0 --kube-context obs -n monitoring --create-namespace -f manifests/monitoring/kps-values.yaml --wait --timeout 10m | head -8"
r "kubectl --context obs -n monitoring get pods"
