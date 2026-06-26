# Report 81: Security Audit

**Files:** app.js, worker/src/index.js, wrangler.toml, index.html
**Date:** 2026-06-22

---

## Already Implemented (Good)

| Feature | Implementation | Location |
|---------|---------------|----------|
| API key obfuscation | `KEY_STORE` — reverse string + Base64 in localStorage | app.js:180-249 |
| HTTPS enforced | All API URLs use `https://` | app.js:173, worker redirects |
| Session cookies | HttpOnly, Secure, SameSite=None, 7-day expiry | worker:90-96 |
| JWT authentication | HS256-signed JWT with 7-day expiry, verified on each request | worker:48-82 |
| OAuth state verification | CSRF protection with random state stored in D1 | worker:99-103, 230-267 |
| Deletes used OAuth state | Prevents replay of callback state | worker:267 |
| Content-Type enforcement | All API responses set proper Content-Type headers | worker:19-28 |
| Cache-Control: no-store | Auth endpoints prevent caching | worker:27 |

---

## Remaining Security Risks

### RISK 1: No Content Security Policy (CSP) Headers
**Severity: HIGH**

The app serves dynamic HTML content via `innerHTML` assignments throughout. There are zero CSP headers configured on either the frontend (index.html has no `<meta http-equiv="Content-Security-Policy">`) or the worker (no CSP headers in any response).

**Impact:** An XSS vulnerability in any `innerHTML` assignment or inline `onclick` handler would allow arbitrary script execution. The app uses inline event handlers extensively (83+ `onclick=` attributes in index.html, plus string-based event handlers built at runtime in app.js).

**Evidence:**
- No CSP meta tag in index.html (searched: no `Content-Security-Policy` in any file)
- Inline `onclick` handlers on every interactive element
- `innerHTML` used in `renderRecentProjects()`, `renderSurvey()`, `renderArtifacts()`, `renderPreview()`, `renderResultHistory()`, etc.

### RISK 2: localStorage Key Obfuscation Is NOT Encryption
**Severity: HIGH**

The `KEY_STORE` module (app.js:180-249) stores API keys using `btoa(key.split('').reverse().join(''))` — reverse string + Base64 encoding. This is trivially reversible.

**Impact:** Anyone with DevTools access can:
1. Run `localStorage.getItem('prdkit_key_obf')` and decode the key
2. Set a breakpoint at `KEY_STORE.set()` and read the plaintext key from the call stack
3. Inspect memory in the debugger

The code's own comment admits this: *"reverse + base64 — NOT encryption, just not plaintext"* and *"DevTools, extensions, malware can still access"*.

**Mitigation already in place:** Keys are stored in localStorage, NOT in the state object, and are cleared from state after being set. This prevents accidental key exposure in state persistence.

### RISK 3: No Rate Limiting on Worker Endpoints
**Severity: MEDIUM**

The worker (src/index.js) has zero rate limiting on any endpoint:
- `POST /api/chat` — proxies AI API calls (cost exposure)
- `POST /api/verify-key` — can be hammered to probe API keys
- `GET /auth/google` — can trigger OAuth flow repeatedly
- `POST /api/history`, `DELETE /api/providers`, etc.

**Impact:** An attacker with the worker URL could:
- Run up AI API costs by spamming `/api/chat`
- Probe the verify-key endpoint for key validation
- Flood the OAuth endpoint with redirect loops

### RISK 4: DevTools / Breakpoint Access to KEY_STORE
**Severity: MEDIUM**

Any user can open DevTools, set a breakpoint on `KEY_STORE.set()` (app.js:184), and read the plaintext API key from the `key` parameter. This is a browser limitation, not a code bug, but it means the obfuscation provides only a false sense of security.

**Impact:** Same as Risk 2 — API key extraction via DevTools or extension.

### RISK 5: No Input Sanitization on Rendered Content
**Severity: MEDIUM**

Several render functions use `escapeHtml()` for user-generated content (good), but many do not:

**Vulnerable patterns (incomplete or missing sanitization):**
- `renderMarkdown()` (app.js:6393) — converts markdown to HTML without sanitizing embedded HTML
- `printArtifact()` (app.js:6453) — writes directly into a new window's document via `win.document.write()` with artifact content
- `renderRecentProjects()` — uses `escapeHtml()` for name but builds inline `onclick` handlers with string interpolation (line 4837, 4844)
- Survey options with `escapeHtml()` in index.html templates (lines 3074-3088) — sanitization exists for most paths

### RISK 6: GOOGLE_CLIENT_ID Hardcoded in wrangler.toml
**Severity: MEDIUM**

**Location:** `worker/wrangler.toml` line 12:
```
[vars]
GOOGLE_CLIENT_ID = "666057235205-l1i1lf4rlfdqttb54lfpoml5n1i1ib16"
```

This is checked into source control. While a Google OAuth client ID is not a secret per se (it's exposed to the browser anyway in the OAuth flow), it's bad practice to hardcode secrets in config files. The `GOOGLE_CLIENT_SECRET` is correctly referenced via `env.GOOGLE_CLIENT_SECRET` (an environment variable, not in the file).

**Impact:** LOW direct risk (client ID is public-facing), but signals poor secret management practices.

### RISK 7: No Request Validation Beyond Basic Checks
**Severity: MEDIUM**

The worker validates:
- Existence of required fields (name, API key, etc.)
- But does NOT validate:
  - Input size limits (no maximum body size)
  - Input content type validation beyond "is it JSON?"
  - Schema validation on any endpoint
  - URL sanitization on `baseUrl` parameter

**Evidence:** `baseUrl` at worker lines 726-730 is used directly in `fetch()` without validation. An attacker could potentially inject a malicious URL.

### RISK 8: Migration Runs on Every Request
**Severity: LOW**

The `runMigration()` function (worker:121-155) runs `CREATE TABLE IF NOT EXISTS ...` and `ALTER TABLE` statements on every single request. While `IF NOT EXISTS` prevents errors, it adds ~10-50ms latency to every request.

**Impact:** Minor performance overhead. No security impact.

### RISK 9: No CORS for Non-Vercel Origins
**Severity: LOW**

The worker's credentialed CORS header (`CORS_CRED`) only allows `https://prdkit.vercel.app`. The permissive CORS (`CORS`) allows `*` but is only used for non-auth endpoints. This is correct behavior for the current deployment.

However, if the app were deployed to a different domain, auth cookies wouldn't be sent and login would fail.

---

## Risk Summary

| # | Risk | Severity | Effort to Fix |
|---|------|----------|---------------|
| 1 | No CSP headers | **HIGH** | Low (add meta tag + headers) |
| 2 | Key obfuscation not encryption | **HIGH** | Medium (use Web Crypto API subtle.encrypt) |
| 3 | No rate limiting | **MEDIUM** | Medium (KV-based rate counter) |
| 4 | DevTools breakpoint access | **MEDIUM** | Impossible (browser limitation) |
| 5 | No input sanitization on some paths | **MEDIUM** | Low (add escapeHtml calls) |
| 6 | Client ID hardcoded in wrangler.toml | **MEDIUM** | Low (move to env var) |
| 7 | No request size/URL validation | **MEDIUM** | Medium (add validation middleware) |
| 8 | Migration per request | **LOW** | Low (run once at startup) |
| 9 | CORS limited to single origin | **LOW** | Low (add configurable origin list) |

**Overall Security Score: 5/10** — Basic auth and session management are solid. CSP is the most critical gap. API key storage provides only cosmetic protection.
