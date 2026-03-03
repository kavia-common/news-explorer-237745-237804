#!/usr/bin/env bash
set -euo pipefail
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/news-explorer-237745-237804/node_proxy_backend"
cd "$WORKSPACE"
[ -f package.json ] || (echo "ERROR: package.json missing at $WORKSPACE" >&2; exit 4)
# Ensure Node >=18 and npm available
node -v >/dev/null 2>&1 || (echo "ERROR: node not found" >&2; exit 10)
NODE_MAJOR=$(node -v | sed 's/v\([0-9]*\).*/\1/')
if [ "${NODE_MAJOR:-0}" -lt 18 ]; then
  echo "ERROR: Node >=18 required, found $(node -v)" >&2; exit 11
fi
npm --version >/dev/null 2>&1 || (echo "ERROR: npm not found" >&2; exit 12)
# Install dependencies non-interactively: prefer package-lock.json -> npm ci
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund --silent || (echo "ERROR: npm ci failed" >&2; exit 5)
else
  npm i --no-audit --no-fund --silent || (echo "ERROR: npm i failed" >&2; exit 6)
fi
# verify runtime modules (fail fast)
node -e "require('express'); require('axios'); require('express-rate-limit'); require('node-cache'); require('dotenv');" || (echo 'ERROR: missing runtime dependencies after install' >&2; exit 7)
# verify dev modules
node -e "require('jest'); require('supertest'); require('eslint');" || (echo 'ERROR: missing devDependencies (jest/supertest/eslint) after install' >&2; exit 8)
# create optional post-install helper only if writable
if touch "$WORKSPACE/.writable_test" 2>/dev/null; then
  rm -f "$WORKSPACE/.writable_test"
  mkdir -p "$WORKSPACE/.init"
  cat > "$WORKSPACE/.init/post_install.sh" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
# optional helper: run lint/test quickly
cd "$(dirname "$0")/.."
if [ -x ./node_modules/.bin/eslint ]; then
  ./node_modules/.bin/eslint . --ext .js || true
fi
npm test --silent || true
SH
  chmod 0755 "$WORKSPACE/.init/post_install.sh" || true
else
  echo "NOTICE: workspace not writable; skipping creation of post-install helper. If you previously saw '404: No agents connected', ensure your file-write agent can write to $WORKSPACE" >&2
fi
