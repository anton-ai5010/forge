---
name: deployment
description: Use when setting up CI/CD pipelines, Dockerizing applications, choosing deployment strategies, or preparing production releases — triggers on "deploy", "Docker", "CI/CD", "pipeline", "rollback", "health check"
---

# Deployment

## The Iron Law

```
NO PRODUCTION DEPLOYMENT WITHOUT ROLLBACK STRATEGY AND HEALTH CHECK
```

## Overview

"Works on my machine" is not a deployment strategy. If you can't roll back in under 5 minutes, you're not ready to deploy.

## Rationalizations (excuses to catch)

| Excuse | Reality |
|--------|---------|
| "It's a small change, no pipeline needed" | Small changes cause big outages |
| "We'll add health checks later" | Later = after the first outage |
| "Rollback plan isn't needed for this" | Every deploy needs a rollback plan, no exceptions |
| "Docker is overkill for this project" | Docker is the minimum for reproducible deploys |
| "We'll just SSH in and restart" | Manual deploys = manual mistakes |
| "Staging is a waste of time" | Production is not your staging environment |

## Red Flags — STOP

- "Let me just deploy this real quick" — rush = incident
- "The tests are flaky, let me skip them" — fix the tests, then deploy
- "I'll set up monitoring after launch" — you won't know you're down
- "It worked in dev, it'll work in prod" — environment differences kill

## Process

### Step 1: Detect existing infrastructure

```bash
# What's already here?
ls Dockerfile docker-compose.yml .github/workflows/*.yml \
   .gitlab-ci.yml fly.toml vercel.json k8s/ 2>/dev/null
```

Check environment: `docker --version`, `ssh server "docker ps"` (if Docker server available).

### Step 2: Choose deployment strategy

```
Is it a new project?
  └─ Yes → Rolling (simplest, good default)
Does it need zero downtime?
  └─ Yes → Blue-Green (instant traffic switch)
Is it a high-risk change to a large userbase?
  └─ Yes → Canary (gradual rollout)
Is it dev/staging only?
  └─ Yes → Recreate (stop old, start new)
```

| Strategy | When | Rollback Speed |
|----------|------|---------------|
| **Rolling** | Default for most apps | ~1 min (redeploy previous) |
| **Blue-Green** | Zero-downtime required | Instant (switch traffic) |
| **Canary** | High-risk changes | Instant (route 100% to stable) |
| **Recreate** | Dev/staging only | N/A |

### Step 3: Dockerize (if needed)

Compressed multi-stage pattern (adapt to your stack):

```dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --production

FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

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

Key rules: multi-stage build, non-root user, pinned versions (not `latest`), HEALTHCHECK, no secrets in image, `.dockerignore` covers `.git node_modules .env tests`.

### Step 4: Set up CI/CD pipeline

Pipeline stages — order matters, never skip:

```
lint → typecheck → test → build → deploy staging → smoke test → deploy prod → health check
```

Each catches different bugs: lint (style), typecheck (types), test (logic), build (deps), smoke test (integration). Define stages in `.github/workflows/deploy.yml` or equivalent. Use environment protection rules for production.

### Step 5: Add health checks

Every service needs two endpoints:

```
GET /health → 200 { status: "ok" }           — liveness: process alive
GET /ready  → 200 { status: "ready" }         — readiness: can serve traffic
              503 { status: "not ready" }        (checks DB, cache, etc.)
```

Wire `/health` into Docker HEALTHCHECK, load balancer, and CI post-deploy verification.

### Step 6: Write rollback plan

Document BEFORE deploying:

```
1. Quick rollback (<5 min): redeploy previous image tag
2. If DB migrated: run rollback migration, then redeploy
3. If rollback impossible: hotfix branch from previous release tag
```

For blue-green: switch traffic back to previous version (instant).

## Pre-Deploy Checklist

```
[ ] All tests pass (CI green)
[ ] Health check endpoints exist (/health, /ready)
[ ] Environment variables documented (.env.example)
[ ] Secrets not in code or Docker image
[ ] Rollback plan written
[ ] DB migration has rollback script (if applicable)
[ ] Docker image builds and runs locally
[ ] .dockerignore excludes sensitive/unnecessary files
[ ] HTTPS configured for production
[ ] Monitoring/logging configured
```

## Output

Save deployment config to `.forge/plans/deploy-{name}.md`:

```
## Deployment: {project}
Strategy: Rolling / Blue-Green / Canary
Infrastructure: Docker + {platform}
Health: /health (liveness), /ready (readiness)
Rollback: redeploy previous tag / switch traffic back
Pipeline: lint → typecheck → test → build → deploy → healthcheck
```

## Integration

**Called after:** implementation complete
**Called before:** `forge:finishing-a-development-branch` (merge/PR)
**Works with:** `forge:security-review` (security before deploy)
