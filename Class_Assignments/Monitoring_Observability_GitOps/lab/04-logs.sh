#!/usr/bin/env bash
# Logs: structured JSON logs from the pods, filtered with kubectl + jq, and Kubernetes events.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 04-logs
c "raw JSON log lines (one object per request, with trace_id/span_id)"
r "kubectl --context obs -n shop logs deploy/payments --tail=3"
c "pretty-print and filter: only the fields we care about, from all shop pods"
r "kubectl --context obs -n shop logs -l app=shop --tail=200 --prefix=false | jq -c 'select(.msg==\"request handled\") | {ts, service, status, duration_ms, trace_id}' | tail -4"
c "count log lines by level and status across the shop pods"
r "kubectl --context obs -n shop logs -l app=shop --tail=-1 | jq -r 'select(.msg==\"request handled\") | \"\\(.level) \\(.status)\"' | sort | uniq -c"
c "slow requests (> 60 ms)"
r "kubectl --context obs -n shop logs -l app=shop --tail=-1 | jq -c 'select(.duration_ms? > 60) | {ts, path, duration_ms, trace_id}' | tail -3"
c "cluster-level events are logs too"
r "kubectl --context obs -n shop get events --sort-by=.lastTimestamp | tail -6"
