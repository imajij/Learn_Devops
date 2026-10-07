#!/usr/bin/env bash
# Grafana was OOMKilled with a 256Mi memory limit; raise it to 512Mi with a helm upgrade.
source "$(dirname "$0")/lib.sh"; cd "$ROOT"
step 01b-grafana-oom
r "kubectl --context obs -n monitoring get pods -l app.kubernetes.io/name=grafana"
r "kubectl --context obs -n monitoring describe pod -l app.kubernetes.io/name=grafana | grep -A5 'Last State'"
r "helm upgrade kps prometheus-community/kube-prometheus-stack --version 92.1.0 --kube-context obs -n monitoring -f manifests/monitoring/kps-values.yaml --wait --timeout 6m | grep -E 'STATUS|REVISION'"
r "kubectl --context obs -n monitoring get pods -l app.kubernetes.io/name=grafana"
r "kubectl --context obs -n monitoring get deploy kps-grafana -o jsonpath='{.spec.template.spec.containers[?(@.name==\"grafana\")].resources}'; echo"
