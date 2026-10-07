# Shared helpers for the lab scripts (sourced by run.sh).
# r  : print the command with a "$ " prompt, then run it (stdout+stderr captured)
# c  : print a "### " comment line
# ts : print a timestamped comment
# step <name> : send everything that follows to lab/<name>.txt
LAB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$LAB")"
K="kubectl --context k8s-b"
r(){ echo "\$ $*"; eval "$@" 2>&1; }
c(){ echo "### $*"; }
ts(){ echo "### [$(date +%H:%M:%S)] $*"; }
step(){ exec > "$LAB/$1.txt"; }
waitfor(){ sleep "$1"; }
