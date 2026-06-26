# Report 83: API Worker Audit

**File:** worker/src/index.js (891 lines), wrangler.toml
**Date:** 2026-06-22

---

## Overview

The PRDKit AI Proxy Worker acts as middleware between the SPA frontend and:
1. Google OAuth (authentication)
2. AI provider APIs (chat completions proxy)
3. D1 database (settings, providers, history, auth states)
4. API key verification service

It runs on Cloudflare Workers with 891 lines of JavaScript.

---

## Endpoint Inventory

| Method | Path | Auth Required | Description |
|--------|------|--------------|-------------|
| GET | `/auth/google` | No | Initiate Google OAuth redirect |
| GET | `/auth/callback` | No | Handle OAuth callback + set session |
| GET | `/auth/me` | No (returns null if not authed) | Get current user info |
| POST | `/auth/logout` | No | Clear session cookie |
| GET | `/api/providers` | Optional | List providers + active config |
| POST | `/api/providers` | Optional | Add/update a provider |
| DELETE | `/api/providers` | Optional | Delete a provider |
| GET | `/api/config` | Optional | Get combined config |
| POST | `/api/config` | Optional | Save config |
| POST | `/api/models` | Optional | Fetch models from a provider base URL |
| POST | `/api/chat` | Optional | Proxy AI chat completion request |
| GET | `/api/history` | Optional | List project history |
| POST | `/api/history` | Optional | Save/update a project |
| DELETE | `/api/history` | Optional | Delete a project entry |
| POST | `/api/verify-key` | No | Verify API key + fetch models |

---

## Issues Found

### ISSUE 1: `PROVIDER_LIST` Not Defined in Worker
**Severity: HIGH**

**Location:** worker/src/index.js, lines 870-871

```javascript
const provider = PROVIDER_LIST.find(p => p.type === providerType) || 
                PROVIDER_LIST.find(p => p.baseUrl && cleanBase.includes(...));
```

`PROVIDER_LIST` is referenced but **never defined anywhere** in the worker file. It is defined in the frontend (`app.js:6862`), but the worker runs in a separate Cloudflare Workers runtime and does not have access to the frontend's global scope.

**Impact:** When the `/api/verify-key` endpoint cannot fetch models from the API directly, it tries to fall back to `PROVIDER_LIST` — which will throw a `ReferenceError: PROVIDER_LIST is not defined`. The catch block at line 882 catches this and returns a 502 error, so the endpoint doesn't crash entirely, but the fallback logic is completely broken.

**Reproduction:** Verify a key for a provider whose `/models` endpoint doesn't respond. Instead of falling back to known models, the worker crashes to 502.

### ISSUE 2: No Rate Limiting
**Severity: MEDIUM**

Zero rate limiting anywhere in the worker. All endpoints are unprotected against:
- Brute force (verify-key endpoint can be hammered)
- Cost exposure (chat endpoint proxies to paid AI APIs)
- Resource exhaustion (D1 queries on every request)

**Cloudflare Workers rate limiting is available as a paid add-on,** but nothing is configured at the code level either.

### ISSUE 3: No Request Validation Beyond Basic Checks
**Severity: MEDIUM**

The worker validates:
- Required field existence (name, apiKey, etc.)
- But NOT:
  - Maximum request body size
  - Schema validation
  - Input length limits
  - URL format validation on `baseUrl`

**Risky patterns:**

1. **`baseUrl` used in fetch without validation** (line 726):
   ```javascript
   const res = await fetch(`${base.replace(/\/+$/, '')}/chat/completions`, { ... });
   ```
   An attacker could pass a malicious `baseUrl` to the `/api/chat` endpoint.

2. **`body.messages` passed directly to AI API** (line 733):
   ```javascript
   body: JSON.stringify({ model, messages, temperature, max_tokens }),
   ```
   No sanitization or size limits on the messages array.

3. **`JSON.parse()` without try/catch** (worker lines 199, 759, 774, 795):
   ```javascript
   return { providers: JSON.parse(raw), seeded: false };
   ```
   If `raw` contains invalid JSON (corrupted data), this throws uncaught.

### ISSUE 4: Google Client ID Hardcoded in wrangler.toml
**Severity: LOW-MEDIUM**

**File:** `wrangler.toml` line 12:
```
[vars]
GOOGLE_CLIENT_ID = "666057235205-l1i1lf4rlfdqttb54lfpoml5n1i1ib16"
```

This is checked into version control. The client ID is not a secret (it's exposed to the browser during OAuth), but:
- It prevents using different client IDs per environment (dev/staging/prod)
- It establishes a bad pattern for future secret management
- `GOOGLE_CLIENT_SECRET` is correctly an environment variable (not in the file)

**Recommendation:** Move to `env.GOOGLE_CLIENT_ID` alongside the secret.

### ISSUE 5: Migration Runs on Every Request
**Severity: LOW**

The `runMigration()` function (lines 121-155) runs on **every single HTTP request**:

```javascript
// Run migration on every request (harmless IF NOT EXISTS)
await runMigration();
```

It executes `CREATE TABLE IF NOT EXISTS` and `ALTER TABLE` statements on every invocation. While `IF NOT EXISTS` prevents errors:
- Adds ~10-50ms latency to every request
- The `ALTER TABLE settings ADD COLUMN user_id` will throw an error on subsequent runs (caught silently, but still hits D1)

**Recommendation:** Run migration once at worker startup (in a `scheduled` handler or using a flag check), not on every fetch.

### ISSUE 6: CORS Limited to Single Origin
**Severity: LOW**

The credentialed CORS header allows only `https://prdkit.vercel.app`:

```javascript
const CORS_CRED = {
  'Access-Control-Allow-Origin': 'https://prdkit.vercel.app',
  ...
};
```

If the frontend is ever deployed to a staging domain, a custom domain, or for local development, auth cookies will not be sent and all auth-required flows will fail. This is by design for production, but makes local development harder.

### ISSUE 7: Session Cookie Set Without Domain Attribute
**Severity: LOW**

```javascript
function setSessionCookie(token) {
  return `prdkit_session=${token}; Path=/; HttpOnly; SameSite=None; Max-Age=604800; Secure`;
}
```

No `Domain` attribute is set. This means the cookie is scoped to the hostname of the worker (prdkit-ai-proxy.halugoods-indonesia.workers.dev). This is correct behavior — adding a Domain attribute would make the cookie available to subdomains unnecessarily.

---

## Strengths

| Feature | Notes |
|---------|-------|
| OAuth state verification | CSRF token stored in D1, verified on callback, deleted after use |
| JWT with expiry | 7-day expiry, verified on every auth-required request |
| HttpOnly + Secure cookies | Session token not accessible to JavaScript |
| Per-user data isolation | Settings and providers are scoped by `userId` |
| `no-store` cache headers | Auth responses won't be cached by CDNs or proxies |
| Graceful error handling | All endpoints return JSON error responses (no stack traces exposed) |
| D1 parameterized queries | No SQL injection risks — all user inputs use `.bind()` |

---

## Overall Assessment

**Score: 6/10** — Solid authentication foundation, but significant gaps in:
- Rate limiting (critical for a proxy to paid AI APIs)
- Input validation (could lead to request smuggling or abuse)
- `PROVIDER_LIST` reference bug (broken fallback path)
- Migration per request (performance waste)

### Priority Fixes

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | Define `PROVIDER_LIST` or remove the fallback reference | 10 min | Fixes broken endpoint path |
| 2 | Add rate limiting to `/api/chat` and `/api/verify-key` | 2 hours | Prevents cost abuse |
| 3 | Add max body size limit | 10 min | Prevents OOM/resource attacks |
| 4 | Validate `baseUrl` format before fetch | 15 min | Prevents SSRF-like abuse |
| 5 | Move migration to startup (use `env.MIGRATED` flag) | 30 min | Reduces latency on every request |
| 6 | Move GOOGLE_CLIENT_ID to env var | 5 min | Enables per-env config |
