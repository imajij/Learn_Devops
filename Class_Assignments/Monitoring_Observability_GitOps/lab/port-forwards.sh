#!/usr/bin/env bash
# Port-forwards used during the lab (each restarts itself if the connection drops).
#   Prometheus 29090, Grafana 23000, Alertmanager 29093, Jaeger 26686, git server 23001, Argo CD 28080
pf(){ while true; do kubectl --context obs -n "$1" port-forward "$2" "$3" >/dev/null 2>&1; sleep 2; done & }
pf monitoring svc/kps-prometheus 29090:9090
pf monitoring svc/kps-grafana 23000:80
pf monitoring svc/kps-alertmanager 29093:9093
pf observability svc/jaeger 26686:16686
pf git svc/git-server 23001:3000
pf argocd svc/argocd-server 28080:443
wait
