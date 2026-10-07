#!/usr/bin/env bash
# Metrics: raw /metrics output, Prometheus targets, PromQL for traffic, CPU, memory and health.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 03a-metrics-endpoint
c "what Prometheus scrapes: the app's /metrics endpoint (Prometheus text format)"
r "kubectl --context obs -n shop exec deploy/payments -- python -c \"import urllib.request as u; print(u.urlopen('http://localhost:8080/metrics').read().decode())\" | grep -vE '_bucket.*le=\\\"0.0(05|1)\\\"' | head -32"
step 03b-targets
c "Prometheus scrape targets (health / job / URL) - app pods discovered via the ServiceMonitor"
r "targets"
step 03c-promql
c "traffic: requests per second by service and status code"
r "pq 'sum by (service, code) (rate(http_requests_total{namespace=\"shop\",path!=\"/metrics\"}[1m]))'"
c "latency: p95 of /order in seconds"
r "pq 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{namespace=\"shop\",path=\"/order\"}[5m])))'"
c "CPU utilization: cores used per pod (cAdvisor)"
r "pq 'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace=\"shop\",container!=\"\"}[1m]))'"
c "memory utilization: working set per pod in MiB"
r "pq 'sum by (pod) (container_memory_working_set_bytes{namespace=\"shop\",container!=\"\"}) / 1024 / 1024'"
c "application health: scrape status and available replicas"
r "pq 'up{namespace=\"shop\"}'"
r "pq 'max by (deployment) (kube_deployment_status_replicas_available{namespace=\"shop\"})'"
c "same CPU/memory numbers from metrics-server"
r "kubectl --context obs -n shop top pods"
r "kubectl --context obs top nodes"
