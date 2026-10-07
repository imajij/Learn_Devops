#!/usr/bin/env bash
# Simulated incident. Phase "errors+cpu": payments starts failing 40% of calls and one shop pod burns CPU.
# Phase "down": the payments Deployment is scaled to 0 (pod down). Phase "recover": everything back to normal.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
case "$1" in
errors-cpu)
  step 05a-incident-errors-cpu
  ts "baseline: alerts for namespace shop"
  r "alerts"
  r "pq 'sum by (service) (rate(http_requests_total{namespace=\"shop\",code=~\"5..\"}[1m]))'"
  ts "INCIDENT START: inject 40% failures in payments, burn CPU in one shop pod"
  PAY=$(kubectl --context obs -n shop get pod -l app=payments -o name | head -1)
  SHOP=$(kubectl --context obs -n shop get pod -l app=shop -o name | head -1)
  r "admin $PAY '/admin/errors?pct=40'"
  r "admin $SHOP '/admin/burn?seconds=420'"
  waitalert ShopHighErrorRate 240
  waitalert ShopHighCPU 240
  step 05a2-incident-alerts
  ts "alerts while the incident is running"
  r "alerts"
  r "pq 'sum by (service) (rate(http_requests_total{namespace=\"shop\",code=~\"5..\"}[1m])) / sum by (service) (rate(http_requests_total{namespace=\"shop\",path!=\"/metrics\"}[1m]))'"
  r "pq 'sum by (pod) (rate(container_cpu_usage_seconds_total{namespace=\"shop\",container=\"app\"}[1m]))'"
  r "kubectl --context obs -n shop top pods"
  ;;
errors-logs)
  step 05b-incident-logs
  c "during the incident: error log lines carry the trace_id of the failing request"
  r "kubectl --context obs -n shop logs -l app=shop --tail=300 | jq -c 'select(.level==\"error\") | {ts, service, status, trace_id}' | tail -3"
  r "kubectl --context obs -n shop logs -l app=payments --tail=300 | jq -c 'select(.level==\"error\") | {ts, service, status, trace_id}' | tail -3"
  r "kubectl --context obs -n shop logs -l app=shop --tail=-1 | jq -r 'select(.msg==\"request handled\") | \"\\(.level) \\(.status)\"' | sort | uniq -c"
  c "Alertmanager received the firing alerts (it would route them to Slack/e-mail/PagerDuty)"
  r "curl -s http://localhost:29093/api/v2/alerts | jq -r '.[] | select(.labels.alertname|startswith(\"Shop\")) | \"\\(.status.state)\t\\(.labels.alertname)\t\\(.labels.severity)\t\\(.startsAt)\"'"
  ;;
down)
  step 05c-incident-pod-down
  ts "fix phase 1: stop error injection; then take payments down completely"
  PAY=$(kubectl --context obs -n shop get pod -l app=payments -o name | head -1)
  r "admin $PAY '/admin/errors?pct=0'"
  r "kubectl --context obs -n shop scale deploy/payments --replicas=0"
  r "kubectl --context obs -n shop get deploy payments"
  waitalert ShopNoReadyReplicas 180
  r "alerts"
  waitalert ShopHighErrorRate 120
  r "alerts"
  c "what the shop sees while payments has no pods (jq -R + fromjson? skips any non-JSON line)"
  r "kubectl --context obs -n shop logs -l app=shop --tail=50 | jq -cR 'fromjson? | select(.level==\"error\") | {ts, status, duration_ms, trace_id}' | tail -3"
  r "kubectl --context obs -n shop get endpoints payments"
  ;;
recover)
  step 05d-recover
  ts "recovery: scale payments back up and wait for the alerts to resolve"
  r "kubectl --context obs -n shop scale deploy/payments --replicas=1"
  r "kubectl --context obs -n shop rollout status deploy/payments --timeout=90s"
  end=$(( $(date +%s) + 360 )); while [ $(date +%s) -lt $end ]; do n=$(curl -s "$P/api/v1/alerts" | jq '[.data.alerts[]|select(.labels.alertname|startswith("Shop"))]|length'); ts "shop alerts still active: $n"; [ "$n" = 0 ] && break; sleep 20; done
  r "alerts"
  r "pq 'sum by (service, code) (rate(http_requests_total{namespace=\"shop\",path!=\"/metrics\"}[1m]))'"
  ;;
esac
