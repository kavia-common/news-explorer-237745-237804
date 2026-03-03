#!/usr/bin/env bash
set -euo pipefail

# Authoritative workspace from container info
WORKSPACE="/home/saqiba/Desktop/test_rle/workspace/tmp/kavia/code-generation/news-explorer-237745-237804/node_proxy_backend"

# Validate node & npm
command -v node >/dev/null 2>&1 || { echo "node not found on PATH" >&2; exit 2; }
command -v npm >/dev/null 2>&1 || { echo "npm not found on PATH" >&2; exit 2; }
NODE_V=$(node -v || true)
NPM_V=$(npm -v || true)
echo "node: ${NODE_V:-unknown}, npm: ${NPM_V:-unknown}"

# Ensure workspace exists and write files
mkdir -p "$WORKSPACE" && cd "$WORKSPACE"

# package.json
cat > package.json <<'EOF'
{
  "name": "node_proxy_backend",
  "version": "0.1.0",
  "private": true,
  "type": "commonjs",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "lint": "eslint . --ext .js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4",
    "axios": "^1",
    "express-rate-limit": "^6",
    "node-cache": "^5",
    "dotenv": "^16"
  },
  "devDependencies": {
    "eslint": "^8",
    "jest": "^29",
    "nodemon": "^2",
    "supertest": "^6"
  }
}
EOF

# app.js
cat > app.js <<'EOF'
const express = require('express');
const axios = require('axios');
const rateLimit = require('express-rate-limit');
const NodeCache = require('node-cache');
require('dotenv').config();
const app = express();
const cache = new NodeCache({ stdTTL: 60 });
app.get('/healthz', (req, res) => res.json({ status: 'ok' }));
const limiter = rateLimit({ windowMs: 60 * 1000, max: Number(process.env.RATE_LIMIT_MAX || 40) });
app.use('/proxy', limiter);
app.get('/proxy', async (req, res) => {
  try {
    const q = req.query.q || 'latest';
    const cacheKey = `news:${q}`;
    const cached = cache.get(cacheKey);
    if (cached) return res.json({ cached: true, data: cached });
    const NEWS_API_KEY = process.env.NEWS_API_KEY || '';
    if (!NEWS_API_KEY) return res.status(500).json({ error: 'NEWS_API_KEY not set' });
    const url = `https://newsapi.org/v2/everything?q=${encodeURIComponent(q)}`;
    const r = await axios.get(url, { headers: { 'X-Api-Key': NEWS_API_KEY } });
    const data = r.data;
    cache.set(cacheKey, data);
    res.json({ cached: false, data });
  } catch (err) {
    console.error(err && err.stack ? err.stack : err);
    res.status(500).json({ error: 'internal_error' });
  }
});
module.exports = app;
EOF

# server.js
cat > server.js <<'EOF'
const app = require('./app');
const PORT = process.env.PORT || 3000;
const server = app.listen(PORT, () => console.log(`proxy listening ${PORT}`));
process.on('SIGTERM', () => server.close(() => process.exit(0)));
module.exports = server;
EOF

# .env.example
cat > .env.example <<'EOF'
# Copy to .env and set your NEWS_API_KEY for positive-path manual testing
NODE_ENV=development
NEWS_API_KEY=your_api_key_here
PORT=3000
EOF

# README.md
cat > README.md <<'EOF'
# node_proxy_backend

Development scaffold. Copy .env.example to .env and set NEWS_API_KEY to test positive proxy behavior. Run 'npm ci' after scaffold and 'npm run dev' for hot reload.
EOF

# .eslintrc.json
cat > .eslintrc.json <<'EOF'
{
  "env": { "node": true, "jest": true, "es2022": true },
  "extends": "eslint:recommended",
  "parserOptions": { "ecmaVersion": 2022 },
  "rules": {}
}
EOF

# jest.config.cjs
cat > jest.config.cjs <<'EOF'
module.exports = { testEnvironment: 'node', verbose: false };
EOF

# tests
mkdir -p __tests__
cat > __tests__/proxy.test.js <<'EOF'
const request = require('supertest');
const app = require('../app');

describe('basic endpoints', () => {
  test('health endpoint responds', async () => {
    const res = await request(app).get('/healthz');
    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('status', 'ok');
  });
});
EOF

# bookmarks.json
cat > bookmarks.json <<'EOF'
[]
EOF

# .gitignore
cat > .gitignore <<'EOF'
node_modules/
.env
.logs/
EOF

# Generate package-lock.json only for deterministic installs
npm i --package-lock-only --no-audit --no-fund --silent || true

# Print summary output
echo "scaffolded project at: $WORKSPACE"
