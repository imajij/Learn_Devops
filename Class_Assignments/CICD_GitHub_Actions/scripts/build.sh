#!/usr/bin/env bash
# Build step: package the app into a versioned tarball plus a build-info file.
# The CI job uploads dist/ as an artifact; the CD job never rebuilds from scratch.
set -euo pipefail
VERSION=$(python3 -c "import app; print(app.__version__)")
SHA=${GITHUB_SHA:-local}
SHORT_SHA=${SHA:0:7}
rm -rf dist && mkdir -p dist
tar -czf "dist/task-tracker-${VERSION}-${SHORT_SHA}.tar.gz" app requirements.txt
cat > dist/build-info.txt <<INFO
app=task-tracker
version=${VERSION}
commit=${SHA}
built_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
built_by=${GITHUB_WORKFLOW:-manual}/${GITHUB_JOB:-manual} run ${GITHUB_RUN_NUMBER:-0}
INFO
echo "Build output:"; ls -l dist
cat dist/build-info.txt
