#!/bin/bash
# Lab script for Session 15 (Helm). Usage: bash lab/run.sh <step>
source "$(dirname "$0")/lib.sh"
cd "$ROOT"
H="helm --kube-context k8s-b"
case "$1" in
00-version)
  step 00-version
  r helm version
  r $K get nodes
  ;;
01-create)
  step 01-create
  r cd 01-commands
  r helm create demo-chart
  r find demo-chart -type f \| sort
  r "grep -E '^(name|version|appVersion)' demo-chart/Chart.yaml"
  r "grep -A3 '^image:' demo-chart/values.yaml; grep '^replicaCount' demo-chart/values.yaml"
  ;;
02-lint-template)
  step 02-lint-template
  r helm lint 01-commands/demo-chart
  r "helm template demo 01-commands/demo-chart --set image.tag=1.27 | grep -E '^kind|^# Source|image:|replicas:'"
  ;;
03-repo)
  step 03-repo
  r helm repo add bitnami https://charts.bitnami.com/bitnami
  r helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  r helm repo list
  r helm repo update
  ;;
04-search)
  step 04-search
  r helm search repo nginx
  r "helm search repo bitnami/nginx --versions | head -6"
  r "helm search hub grafana --max-col-width 50 | head -8"
  r helm show chart bitnami/nginx \| head -12
  r helm show chart ingress-nginx/ingress-nginx \| head -12
  ;;
05-install)
  step 05-install
  r $H install demo 01-commands/demo-chart --set image.tag=1.27 --wait --timeout 3m
  r $K get deploy,pods,svc -l app.kubernetes.io/instance=demo
  ;;
06-list)
  step 06-list
  r $H list
  r $H list -A
  r $H list -o yaml
  ;;
06b-list-all-helm4)
  step 06b-list-all-helm4
  c "Helm 3's 'helm list --all' does not exist in Helm 4"
  r $H list --all
  r "helm list --help | grep -E -- '--(deployed|failed|pending|superseded|uninstalled|uninstalling)'"
  ;;
07-status)
  step 07-status
  r $H status demo
  ;;
08-get)
  step 08-get
  r $H get values demo
  r "$H get values demo --all | head -15"
  r "$H get manifest demo | grep -E '^# Source|^kind|image:'"
  r $H get notes demo
  r $H get metadata demo
  ;;
09-upgrade)
  step 09-upgrade
  r $H upgrade demo 01-commands/demo-chart --reuse-values --set replicaCount=3 --wait --timeout 3m
  r $K get pods -l app.kubernetes.io/instance=demo
  r $H list
  ;;
10-history)
  step 10-history
  r $H history demo
  ;;
11-rollback)
  step 11-rollback
  r $H rollback demo 1 --wait
  r $K get pods -l app.kubernetes.io/instance=demo
  r $H history demo
  ;;
12-uninstall)
  step 12-uninstall
  r $H uninstall demo
  r $H list
  r $K get all -l app.kubernetes.io/instance=demo
  r $H repo remove ingress-nginx
  r $H repo list
  ;;
20-rb-install)
  step 20-rb-install
  r cat 02-rollback/app-chart/values.yaml
  r $H install rollback-demo 02-rollback/app-chart --wait --timeout 3m
  c "VERIFY revision 1"
  r $K get deploy,pods -l app=rollback-demo-web -o wide
  r "$K exec deploy/rollback-demo-web -- curl -sI localhost | grep Server"
  r $H history rollback-demo
  ;;
21-rb-upgrade1)
  step 21-rb-upgrade1
  r $H upgrade rollback-demo 02-rollback/app-chart --set replicaCount=3 --set image.tag=1.27-alpine --wait --timeout 3m
  sleep 5
  c "VERIFY revision 2"
  r "$K get pods -l app=rollback-demo-web -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready"
  r "$K exec deploy/rollback-demo-web -- cat /etc/os-release | head -2"
  r $H history rollback-demo
  ;;
22-rb-upgrade2)
  step 22-rb-upgrade2
  c "upgrade again with a deliberately bad image tag (reuse the other values)"
  r $H upgrade rollback-demo 02-rollback/app-chart --reuse-values --set image.tag=9.99-doesnotexist
  sleep 40
  c "VERIFY revision 3"
  r $H status rollback-demo \| head -6
  r $K get pods -l app=rollback-demo-web
  r "$K events | grep 9.99-doesnotexist | tail -2 | cut -c1-230"
  r $K rollout status deploy/rollback-demo-web --timeout=10s
  r $H history rollback-demo
  ;;
23-rb-rollback)
  step 23-rb-rollback
  r $H rollback rollback-demo 2 --wait --timeout 3m
  sleep 5
  c "VERIFY after rollback"
  r "$K get pods -l app=rollback-demo-web -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,READY:.status.containerStatuses[0].ready"
  r $H history rollback-demo
  r $H get values rollback-demo
  ;;
24-rb-auto)
  step 24-rb-auto
  c "bonus: let Helm roll back by itself (Helm 4 --rollback-on-failure, was --atomic in Helm 3)"
  r $H upgrade rollback-demo 02-rollback/app-chart --reuse-values --set image.tag=9.99-doesnotexist --rollback-on-failure --timeout 60s
  r $H history rollback-demo
  r $K get pods -l app=rollback-demo-web
  r $H uninstall rollback-demo
  ;;
30-mp-lint)
  step 30-mp-lint
  r cd mini-project
  r find notes-chart -type f \| sort
  r helm lint notes-chart
  r helm lint notes-chart -f notes-chart/values-prod.yaml
  r "helm template notes-dev notes-chart | grep -E '^# Source|^kind|replicas:|image:|environment:'"
  r "helm template notes-dev notes-chart -f notes-chart/values-prod.yaml | grep -E 'replicas:|image:|environment:|cpu:'"
  ;;
31-mp-install)
  step 31-mp-install
  r cd mini-project
  r $H install notes-dev notes-chart --wait --timeout 3m
  r $K get pods -l app.kubernetes.io/instance=notes-dev
  r $K get services -l app.kubernetes.io/instance=notes-dev
  r $K get configmaps -l app.kubernetes.io/instance=notes-dev
  r "$K port-forward svc/notes-dev-notes 8091:80 > /dev/null 2>&1 & PF=\$!; sleep 3"
  r "curl -s localhost:8091 | grep -E '<h1>|environment|<li>'"
  r kill \$PF
  ;;
32-mp-upgrade-prod)
  step 32-mp-upgrade-prod
  r cd mini-project
  r cat notes-chart/values-prod.yaml
  r $H upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --wait --timeout 3m
  r $K get pods -l app.kubernetes.io/instance=notes-dev
  r "$K port-forward svc/notes-dev-notes 8091:80 > /dev/null 2>&1 & PF=\$!; sleep 3"
  r "curl -s localhost:8091 | grep -E '<h1>|environment|<li>'"
  r kill \$PF
  r $H history notes-dev
  ;;
33-mp-upgrade-broken)
  step 33-mp-upgrade-broken
  r cd mini-project
  r $H upgrade notes-dev notes-chart -f notes-chart/values-prod.yaml --set image.tag=broken-tag-does-not-exist
  sleep 40
  r $K get pods -l app.kubernetes.io/instance=notes-dev
  r "$K get pods -l app.kubernetes.io/instance=notes-dev -o custom-columns=POD:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.containerStatuses[0].state.waiting.reason"
  r $H history notes-dev
  ;;
34-mp-rollback)
  step 34-mp-rollback
  r cd mini-project
  r $H rollback notes-dev 2 --wait --timeout 3m
  r $K get pods -l app.kubernetes.io/instance=notes-dev
  r $H history notes-dev
  r "$K port-forward svc/notes-dev-notes 8091:80 > /dev/null 2>&1 & PF=\$!; sleep 3"
  r "curl -s localhost:8091 | grep -E '<h1>|environment|<footer>'"
  r kill \$PF
  ;;
35-mp-uninstall)
  step 35-mp-uninstall
  r $H uninstall notes-dev
  r $K get pods
  r $K get services
  r $H list
  ;;
*) echo "unknown step $1" >&2; exit 1;;
esac
