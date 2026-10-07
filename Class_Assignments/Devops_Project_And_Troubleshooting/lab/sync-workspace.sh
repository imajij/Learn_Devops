#!/usr/bin/env bash
# Copy final-devops-project/ into the Git working copy ~/devops-lab/final/ws (the "GitHub repo"
# that act runs and that is pushed to the in-cluster Git server). Generated folders are excluded.
source "$(dirname "$0")/common.sh"
mkdir -p "$WORK/ws"
rsync -a --delete --exclude .git --exclude node_modules --exclude dist --exclude .pytest_cache \
  --exclude __pycache__ --exclude .coverage --exclude reports --exclude '.terraform*' --exclude '*.tfstate*' \
  "$APP/" "$WORK/ws/"
