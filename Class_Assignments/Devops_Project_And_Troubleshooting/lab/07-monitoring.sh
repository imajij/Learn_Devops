#!/usr/bin/env bash
# Step 7: Prometheus + Grafana (kube-prometheus-stack, trimmed) and the app's ServiceMonitor.
source "$(dirname "$0")/common.sh"
cd "$APP"
r "helm --kube-context final upgrade --install monitoring kube-prometheus-stack --repo https://prometheus-community.github.io/helm-charts --version 92.1.0 -n monitoring --create-namespace -f monitoring/kube-prometheus-stack-values.yaml --wait --timeout 8m 2>&1 | grep -vE '^(W|I)[0-9]{4}' | head -12"
r "$K -n monitoring get pods"
r "$K apply -f monitoring/grafana-dashboard-configmap.yaml"
note "turn on the chart's ServiceMonitor now that the Prometheus Operator CRDs exist (helm upgrade by hand)"
r "helm --kube-context final upgrade campusdesk helm/campusdesk -n campusdesk --reuse-values --set monitoring.serviceMonitor.enabled=true --wait | head -6"
r "$K -n campusdesk get servicemonitor campusdesk-backend -o jsonpath='{.spec}' | jq -c ."
