#!/usr/bin/env bash
# Step 7b: metrics (app /metrics, Prometheus targets + PromQL) and logs, while lab/traffic.sh runs.
source "$(dirname "$0")/common.sh"
note "the app's own /metrics endpoint (not routed by the Ingress, so read it via the Service)"
r "$K -n campusdesk exec deploy/campusdesk-frontend -- wget -qO- http://campusdesk-backend:8000/metrics | grep -E '^(campusdesk_tickets_created_total|http_requests_total\\{handler=\"/api/tickets\")' | head -8"
note "Prometheus (port-forward localhost:9091) - scrape targets for the app"
r "curl -s 'localhost:9091/api/v1/targets?state=active' | jq -r '.data.activeTargets[] | select(.labels.job==\"campusdesk-backend\") | \"\\(.labels.pod)  \\(.scrapeUrl)  health=\\(.health)\"'"
Q(){ r "curl -s localhost:9091/api/v1/query --data-urlencode 'query=$1' | jq -r '.data.result[] | \"\\(.metric.$2 // \"total\")  \\(.value[1] | tonumber | . * 1000 | round / 1000)\"'"; }
Q 'sum by (handler) (rate(http_requests_total{job="campusdesk-backend"}[2m]))' handler
Q 'sum by (status) (rate(http_requests_total{job="campusdesk-backend"}[2m]))' status
Q 'histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{job="campusdesk-backend"}[5m])))' x
Q 'sum by (category) (campusdesk_tickets_created_total)' category
note "logs: structured app log lines from every backend pod"
r "$K -n campusdesk logs -l app=campusdesk-backend --prefix --tail=4 -c api | cut -c1-160"
r "$K -n ingress-nginx logs deploy/ingress-nginx-controller --tail=3 | cut -c1-200"
