---
name: security-review
description: Use when reviewing code before PR/merge, when touching auth/payment/user-data code, or when implementing new endpoints — runs OWASP-based security checklist
---

# Security Review

## Overview

Security bugs are harder to find after merge. Catching them during review costs minutes; fixing them in production costs weeks.

**Core principle:** Every code path that handles user input, credentials, or money gets a security pass.

## The Iron Law

```
NO MERGE WITHOUT SECURITY CHECKLIST FOR CHANGED FILES
```

If changed files touch auth, payments, user data, API endpoints, or file operations — this checklist is mandatory.

## When to Use

**Always before:**
- PR creation / merge
- Deploying to production
- Adding new API endpoints
- Implementing authentication/authorization
- Handling payments or sensitive data
- File uploads / user-generated content

**Especially when:**
- "It's just a small auth change"
- "Only internal users access this"
- "We'll add security later"

## Разведка окружения

- **Serena MCP** — find all callers of a function to trace data flow
- **Context7** — check framework-specific security docs
- **Playwright** — verify security headers in browser

## The Checklist

Run through ALL sections. Mark each item. Skip = documented exception.

### 1. Secrets & Credentials

```
[ ] No hardcoded secrets (API keys, passwords, tokens)
[ ] No secrets in git history (check: git log -p --all -S 'password\|secret\|api_key')
[ ] .env files in .gitignore
[ ] Secrets loaded from environment, not config files
[ ] No secrets in error messages or logs
[ ] No secrets in URL query parameters
```

**Quick check:**
```bash
# Find potential hardcoded secrets
grep -rn "password\|secret\|api_key\|token\|private_key" --include='*.{ts,js,py,go,java,rb}' . \
  | grep -v node_modules | grep -v '.env' | grep -v test
```

### 2. Input Validation

```
[ ] ALL user input validated at entry point (not deep inside)
[ ] SQL: parameterized queries only (no string concatenation)
[ ] HTML: output escaped (XSS prevention)
[ ] File paths: no user input in path construction (path traversal)
[ ] URLs: validated against allowlist for redirects
[ ] JSON: schema validated before processing
[ ] Numbers: range checked (no negative amounts, no overflow)
[ ] Strings: length limited
```

**Red patterns — immediate fix:**
```
❌ `query("SELECT * FROM users WHERE id = " + userId)`
✅ `query("SELECT * FROM users WHERE id = $1", [userId])`

❌ `<div>{userInput}</div>`  (React is safe, raw HTML is not)
✅ `<div>{sanitize(userInput)}</div>` or use framework escaping

❌ `fs.readFile("/uploads/" + req.params.filename)`
✅ `fs.readFile(path.join(UPLOAD_DIR, path.basename(req.params.filename)))`
```

### 3. Authentication & Authorization

```
[ ] Auth check on EVERY endpoint (not just frontend)
[ ] No endpoint accessible without auth (unless intentionally public)
[ ] Role/permission check where needed (admin vs user)
[ ] Token expiration set and enforced
[ ] Password hashing: bcrypt/argon2, NOT md5/sha1/sha256
[ ] Session invalidation on logout
[ ] Rate limiting on login/signup/password-reset
[ ] No user ID from client for authorization decisions (use session)
```

**Red pattern:**
```
❌ DELETE /api/users/:id — checks if logged in, but not if user owns the resource
✅ DELETE /api/users/:id — checks req.user.id === id OR req.user.role === 'admin'
```

### 4. API Security

```
[ ] CORS configured restrictively (not '*' in production)
[ ] Rate limiting on all public endpoints
[ ] Request size limits (body, file uploads)
[ ] No sensitive data in GET parameters (use POST body)
[ ] Error responses don't leak internals (stack traces, DB schema)
[ ] API versioning (breaking changes don't break clients)
[ ] HTTPS enforced (redirect HTTP → HTTPS)
```

### 5. Dependencies

```bash
# Check for known vulnerabilities
npm audit          # Node.js
pip-audit          # Python
go vuln check ./...  # Go
```

```
[ ] No dependencies with known critical CVEs
[ ] Lock file committed (package-lock.json / poetry.lock / go.sum)
[ ] No unnecessary dependencies (smaller surface = fewer vulns)
```

### 6. Data & Privacy

```
[ ] PII not logged (emails, IPs, names — mask or omit)
[ ] Database backups encrypted
[ ] Soft delete for user data (GDPR right to erasure)
[ ] No user data in URLs (analytics/referrer leak)
[ ] Cookies: Secure + HttpOnly + SameSite flags
```

### 7. Error Handling

```
[ ] Errors don't expose internals (no stack traces to users)
[ ] Failed auth returns generic message (not "user not found" vs "wrong password")
[ ] Catch blocks don't swallow errors silently
[ ] Error logging includes context but not sensitive data
```

## Output Format

After completing checklist, produce a security report:

```
## Security Review: {files/feature}
Date: {date}

### PASS
- [x] Secrets: no hardcoded credentials
- [x] Input validation: parameterized queries
- [x] Auth: role checks on all endpoints
...

### FAIL (requires fix)
- [ ] CORS set to '*' in production config → restrict to domain
- [ ] Rate limiting missing on /api/auth/login → add rate limiter

### EXCEPTIONS (documented skip)
- File uploads: not applicable (no upload functionality)

### Verdict: PASS / FAIL (N issues)
```

Save report to `.forge/plans/security-review-{date}.md` if FORGE project.

## Integration

**Called after:** implementation complete, before `forge:verification-before-completion`
**Works with:** `forge:finishing-a-development-branch` — security review before merge
**Records to:** `.forge/decisions.yml` if significant security architecture decisions made

## Red Flags — STOP

- "It's internal, security doesn't matter" → Internal tools get compromised too
- "We'll add auth later" → Unauthed endpoints in git history get found
- "Framework handles security" → Framework handles SOME, you handle the rest
- "It's just a read endpoint" → Read endpoints leak data
- "Only admins use this" → Admin panels are prime targets
