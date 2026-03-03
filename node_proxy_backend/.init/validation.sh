#!/usr/bin/env bash
set -euo pipefail
# Validation script: lint if eslint present, start server.js on explicit port,
# wait for /healthz, negative-path /proxy expecting 500 when NEWS_API_KEY unset,
# capture logs, produce validation_evidence.txt, and cleanly shut down.
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/news-explorer-237745-237804/node_proxy_backend"
cd "$WORKSPACE"
PORT=45123
export PORT
LOG_DIR="$WORKSPACE/.logs"
mkdir -p "$LOG_DIR"
# lint if installed
if [ -x ./node_modules/.bin/eslint ]; then
  ./node_modules/.bin/eslint . --ext .js --max-warnings=0 || (echo 'ERROR: lint failed' >&2; sed -n '1,200p' "$LOG_DIR/server.err" >&2 || true; exit 10)
fi
# start server
node server.js >"$LOG_DIR/server.out" 2>"$LOG_DIR/server.err" &
SERVER_PID=$!
cleanup() {
  if [ -n "${SERVER_PID:-}" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill -TERM "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
}
trap 'cleanup' EXIT
# wait for readiness
MAX_RETRIES=30
i=0
until curl -sS --fail "http://localhost:${PORT}/healthz" >/dev/null 2>&1 || [ $i -ge $MAX_RETRIES ]; do
  i=$((i+1))
  sleep 1
done
if [ $i -ge $MAX_RETRIES ]; then
  echo "ERROR: server did not become ready in time" >&2
  sed -n '1,200p' "$LOG_DIR/server.err" >&2 || true
  sed -n '1,200p' "$LOG_DIR/server.out" >&2 || true
  exit 7
fi
# verify health
health=$(curl -sS "http://localhost:${PORT}/healthz")
echo "$health" | grep -q 'ok' || (echo 'ERROR: health endpoint unexpected' >&2; exit 8)
# negative-path: ensure /proxy returns 500 when NEWS_API_KEY missing
unset NEWS_API_KEY
status_code=$(curl -s -o /tmp/proxy_resp.json -w "%{http_code}" "http://localhost:${PORT}/proxy?q=test")
if [ "$status_code" != "500" ]; then
  echo "ERROR: expected 500 from /proxy when NEWS_API_KEY missing, got $status_code" >&2
  sed -n '1,200p' /tmp/proxy_resp.json >&2 || true
  cleanup
  exit 9
fi
# success evidence
echo "validation: ok" > "$WORKSPACE/validation_evidence.txt"
cat "$WORKSPACE/validation_evidence.txt"
cleanup
