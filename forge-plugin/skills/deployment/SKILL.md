---
name: deployment
description: Use when setting up CI/CD pipelines, Dockerizing applications, configuring deployment strategies, or preparing production releases — covers Docker, GitHub Actions, rollback, and health checks
---

# Deployment Patterns

## Overview

"Works on my machine" is not a deployment strategy. Reproducible builds, automated pipelines, and rollback plans are.

**Core principle:** If you can't roll back in under 5 minutes, you're not ready to deploy.

## The Iron Law

```
NO PRODUCTION DEPLOYMENT WITHOUT ROLLBACK STRATEGY AND HEALTH CHECK
```

## When to Use

- Setting up deployment for a new project
- Dockerizing an application
- Creating CI/CD pipelines
- Preparing a release
- Adding health checks or monitoring
- Changing deployment strategy

## Step 1: Detect Infrastructure

```bash
# Docker
ls Dockerfile docker-compose.yml 2>/dev/null

# CI/CD
ls .github/workflows/*.yml 2>/dev/null    # GitHub Actions
ls .gitlab-ci.yml 2>/dev/null             # GitLab CI
ls Jenkinsfile 2>/dev/null                # Jenkins

# Cloud
ls serverless.yml 2>/dev/null             # Serverless Framework
ls fly.toml 2>/dev/null                   # Fly.io
ls render.yaml 2>/dev/null                # Render
ls vercel.json 2>/dev/null                # Vercel

# Kubernetes
ls k8s/ kubernetes/ charts/ 2>/dev/null
```

## Step 2: Docker (if applicable)

### Multi-stage build (Node.js):

```dockerfile
# Stage 1: Dependencies
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --production

# Stage 2: Build
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

# Stage 3: Production
FROM node:20-alpine
WORKDIR /app
RUN addgroup -g 1001 -S app && adduser -S app -u 1001
COPY --from=deps /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
USER app
EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=3s CMD wget -q --spider http://localhost:3000/health || exit 1
CMD ["node", "dist/index.js"]
```

### Multi-stage build (Python):

```dockerfile
FROM python:3.12-slim AS base
WORKDIR /app

FROM base AS deps
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM deps AS production
COPY . .
RUN adduser --system --no-create-home app
USER app
EXPOSE 8000
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8000"]
```

### Docker Compose (dev + prod):

```yaml
# docker-compose.yml
services:
  app:
    build: .
    ports: ["3000:3000"]
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:3000/health"]
      interval: 10s
      timeout: 3s
      retries: 3

  db:
    image: postgres:16-alpine
    volumes: ["pgdata:/var/lib/postgresql/data"]
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASS}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER}"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
```

### Docker checklist:

```
[ ] Multi-stage build (separate deps/build/prod)
[ ] Non-root user (USER app)
[ ] .dockerignore excludes: .git, node_modules, .env, tests
[ ] HEALTHCHECK defined
[ ] No secrets in image (use env vars or secrets manager)
[ ] Pinned base image versions (node:20-alpine, not node:latest)
[ ] Minimal final image (<200MB target)
```

## Step 3: CI/CD Pipeline

### GitHub Actions (standard template):

```yaml
# .github/workflows/deploy.yml
name: Deploy

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test

  build:
    needs: test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: docker build -t app:${{ github.sha }} .
      - run: docker tag app:${{ github.sha }} app:latest
      # Push to registry...

  deploy:
    needs: build
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: production
    steps:
      # Deploy to target...
      - name: Health check
        run: |
          for i in $(seq 1 30); do
            curl -sf https://app.example.com/health && exit 0
            sleep 2
          done
          echo "Health check failed" && exit 1
```

### Pipeline stages (order matters):

```
lint → typecheck → test → build → deploy staging → smoke test → deploy prod → health check
```

**Never skip stages.** Each catches different issues:
- Lint: style, unused vars, common mistakes
- Typecheck: type errors (TS, mypy, go vet)
- Test: logic errors, regressions
- Build: compilation, missing deps
- Smoke test: integration, real endpoints

## Step 4: Health Checks

**Every deployed service needs a health endpoint:**

```typescript
// /health — basic liveness
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// /ready — readiness (checks dependencies)
app.get('/ready', async (req, res) => {
  try {
    await db.query('SELECT 1');
    // await redis.ping();
    res.status(200).json({ status: 'ready' });
  } catch (err) {
    res.status(503).json({ status: 'not ready', error: err.message });
  }
});
```

**Two health checks:**
- `/health` — "process is alive" (liveness probe)
- `/ready` — "can serve traffic" (readiness probe)

## Step 5: Deployment Strategy

| Strategy | When | Rollback Speed |
|----------|------|---------------|
| **Rolling** | Default for most apps | ~1 min (redeploy previous) |
| **Blue-Green** | Zero-downtime required | Instant (switch traffic) |
| **Canary** | High-risk changes | Instant (route 100% to stable) |
| **Recreate** | Dev/staging only | N/A |

**For most projects:** Rolling deployment is sufficient.

**Blue-Green** (with Docker Compose on a single server):

```bash
#!/bin/bash
# deploy.sh — blue-green on single server

CURRENT=$(docker compose ps --format json | jq -r '.[0].Name' | grep -o 'blue\|green')
NEW=$([[ "$CURRENT" == "blue" ]] && echo "green" || echo "blue")

# Start new version
docker compose -f docker-compose.$NEW.yml up -d --build

# Wait for health
for i in $(seq 1 30); do
  curl -sf http://localhost:${NEW_PORT}/health && break
  sleep 2
done

# Switch traffic (nginx/traefik)
sed -i "s/$CURRENT/$NEW/g" /etc/nginx/conf.d/app.conf
nginx -s reload

# Stop old version (after grace period)
sleep 30
docker compose -f docker-compose.$CURRENT.yml down
```

## Step 6: Rollback Plan

**Document before deploying:**

```markdown
## Rollback: {release}

### Quick rollback (< 5 min)
1. `docker compose pull app:previous-tag`
2. `docker compose up -d`
3. Verify: `curl https://app.example.com/health`

### If database migrated
1. Run rollback migration: `npm run migrate:down`
2. Redeploy previous version
3. Verify health + data integrity

### If rollback impossible
1. Hotfix branch from previous release tag
2. Fix → test → deploy hotfix
3. Estimated time: 30-60 min
```

## Pre-Deploy Checklist

```
[ ] All tests pass (CI green)
[ ] Health check endpoint exists (/health, /ready)
[ ] Environment variables documented (.env.example)
[ ] Secrets not in code or Docker image
[ ] Rollback plan written
[ ] Database migration has rollback script
[ ] Docker image builds and runs locally
[ ] .dockerignore excludes sensitive/unnecessary files
[ ] Monitoring/logging configured
[ ] HTTPS configured (not HTTP in production)
```

## Output

Save deployment config to `.forge/plans/deploy-{name}.md`:

```markdown
## Deployment: {project}
Strategy: Rolling / Blue-Green / Canary
Infrastructure: Docker + {platform}
Health: /health (liveness), /ready (readiness)
Rollback: docker compose pull {previous-tag} && up -d
Pipeline: lint → typecheck → test → build → deploy → healthcheck
```

## Integration

**Called after:** implementation complete
**Called before:** `forge:finishing-a-development-branch` (merge/PR)
**Works with:** `forge:security-review` (security before deploy)
