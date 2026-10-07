#!/usr/bin/env bash
# Step 1: build + unit-test the application on the laptop (no containers).
source "$(dirname "$0")/common.sh"
cd "$APP/application/backend"
note "backend: Python 3.12 virtualenv (uv) + pytest"
r "$WORK/venv/bin/python -V"
r "$WORK/venv/bin/pytest -v --cov=app --cov-report=term"
cd "$APP/application/frontend"
note "frontend: install exact versions from package-lock.json and build"
r "node -v && npm -v"
r "npm ci --no-audit --no-fund"
r "npm run build"
