# Shared helpers for the lab scripts.
# r  : print the command with a "$ " prompt, then run it (stdout+stderr captured)
# c  : print a "### " comment line
# step <name> : send everything that follows to lab/<name>.txt
LAB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$LAB")"
r(){ echo "\$ $*"; eval "$@" 2>&1; }
c(){ echo "### $*"; }
ts(){ echo "### [$(date +%H:%M:%S)] $*"; }
step(){ exec > "$LAB/$1.txt"; }
P=http://localhost:29090   # kubectl port-forward svc/kps-prometheus 29090:9090
# pq '<promql>' : run an instant PromQL query and print "labels => value" lines
pq(){ curl -s -G "$P/api/v1/query" --data-urlencode "query=$1" | jq -r '.data.result[] | "\(.metric | del(.__name__,.endpoint,.instance,.job,.container,.prometheus,.uid) | to_entries | map("\(.key)=\(.value)") | join(",")) => \(.value[1])"'; }
targets(){ curl -s "$P/api/v1/targets?state=active" | jq -r '.data.activeTargets[] | "\(.health)\t\(.labels.job)\t\(.scrapeUrl)"' | sort -k2; }
alerts(){ curl -s "$P/api/v1/alerts" | jq -r '.data.alerts[] | select(.labels.alertname|startswith("Shop")) | "\(.state)\t\(.labels.alertname)\t\(.labels.deployment // .labels.service // .labels.pod)\t\(.annotations.summary)"' | grep . || echo "(no shop alerts pending or firing)"; }
# hit an admin endpoint inside a pod (no curl in the image, so use python)
admin(){ kubectl --context obs -n shop exec "$1" -- python -c "import urllib.request as u; print(u.urlopen('http://localhost:8080$2').read().decode())"; }
# wait until alert $1 is firing (max $2 seconds), printing its state every 15 s
waitalert(){ local end=$(( $(date +%s) + $2 )); while [ $(date +%s) -lt $end ]; do
  s=$(curl -s "$P/api/v1/alerts" | jq -r --arg a "$1" '[.data.alerts[]|select(.labels.alertname==$a)|.state]|unique|join(",")')
  ts "$1 state: ${s:-inactive}"; [[ "$s" == *firing* ]] && return 0; sleep 15; done; }
REPO=$HOME/devops-lab/obs/shop-gitops   # working copy of the GitOps repo (remote = in-cluster git server)
# hit the demo web app's "/" from inside the cluster (prints service + version)
web(){ kubectl --context obs -n gitops-demo exec deploy/web -- python -c "import urllib.request as u; print(u.urlopen('http://web.gitops-demo.svc/').read().decode())"; }
A="--grpc-web"
# wait until Argo CD reports the app Synced to the current HEAD of the repo, printing progress
waitsync(){ local want=$(git -C "$REPO" rev-parse --short HEAD) end=$(( $(date +%s) + ${1:-180} ));
  while [ $(date +%s) -lt $end ]; do
    s=$(kubectl --context obs -n argocd get application shop-web -o jsonpath='{.status.sync.status} {.status.sync.revision} {.status.health.status}')
    ts "argo: sync=$(echo $s|cut -d' ' -f1) rev=$(echo $s|cut -d' ' -f2|cut -c1-7) health=$(echo $s|cut -d' ' -f3)"
    [[ "$s" == "Synced $want"* && "$s" == *Healthy ]] && return 0; sleep 10; done; }
# wait until the Argo CD app health equals $1 (max $2 s)
waithealth(){ local end=$(( $(date +%s) + $2 )); while [ $(date +%s) -lt $end ]; do
  s=$(kubectl --context obs -n argocd get application shop-web -o jsonpath='{.status.sync.status} {.status.sync.revision} {.status.health.status}')
  ts "argo: sync=$(echo $s|cut -d' ' -f1) rev=$(echo $s|cut -d' ' -f2|cut -c1-7) health=$(echo $s|cut -d' ' -f3)"
  [[ "$s" == *" $1" ]] && return 0; sleep 10; done; }
