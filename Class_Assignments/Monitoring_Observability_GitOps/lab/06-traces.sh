#!/usr/bin/env bash
# Traces: take a trace_id from a log line, then fetch the whole request journey from Jaeger.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
J=http://localhost:26686   # kubectl port-forward svc/jaeger 26686:16686
# spans <trace_id> : print the span tree of one trace (service, operation, duration, status code)
spans(){ curl -s "$J/api/traces/$1" | jq -r '.data[0] as $t | $t.spans | sort_by(.startTime)[] |
  "\($t.processes[.processID].serviceName)\t\(.operationName)\t\(.duration/1000|floor) ms\tstatus=\((.tags[]|select(.key=="http.status_code")|.value) // "-")\tparent=\((.references[0].spanID) // "root")\tspan=\(.spanID)"'; }
step 06-traces
c "services that have sent spans to Jaeger"
r "curl -s $J/api/v3/services; echo"
c "1) a FAILED request from the incident: its trace_id appeared in BOTH the shop and payments error logs (05b)"
c "(the payments pod was replaced in 05c, so the log lines come from the saved transcript)"
r "grep f833ba40df1597aad9fb2f6f0ca02fe0 lab/05b-incident-logs.txt"
r "spans f833ba40df1597aad9fb2f6f0ca02fe0"
c "2) a HEALTHY request right now: newest shop log line -> its trace"
POD=$(kubectl --context obs -n shop get pod -l app=shop -o name | head -1)
TID=$(kubectl --context obs -n shop logs $POD --tail=1 | jq -r .trace_id)
r "kubectl --context obs -n shop logs $POD --tail=1 | jq -c '{ts, path, status, duration_ms, trace_id}'"
sleep 2
r "spans $TID"
