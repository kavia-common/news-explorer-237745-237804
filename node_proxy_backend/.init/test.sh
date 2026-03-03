#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/news-explorer-237745-237804/node_proxy_backend"
cd "$WORKSPACE"
export NODE_ENV=test
# Prefer project-local jest
if [ ! -x ./node_modules/.bin/jest ]; then
  echo "ERROR: jest not installed in workspace. Remediation: cd $WORKSPACE && if [ -f package-lock.json ]; then npm ci --no-audit --no-fund --silent; else npm i --no-audit --no-fund --silent; fi" >&2
  exit 5
fi
# Run tests non-interactively, fail-fast
./node_modules/.bin/jest --runInBand --silent || (echo 'ERROR: tests failed' >&2; exit 6)
