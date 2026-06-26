# Report 74: Storage Forensic Audit
**Date:** 2026-06-22
**Scope:** All localStorage keys, D1 Cloudflare tables, cookies, session storage, risks, migration plan.

---

## 1. localStorage Keys

### 1.1 `prdkit_state` — Main Application State
| Property | Value |
|----------|-------|
| **Purpose** | Serializes entire `state` object (24+ fields) |
| **Format** | JSON string |
| **Typical size** | 5-50 KB |
| **Max estimated** | 200-500 KB (with large artifacts + versions + chat history) |
| **Read by** | `loadState()` on every page load |
| **Written by** | `saveState()` on every state mutation |
| **Update frequency** | Frequent (step changes, settings, artifact generation) |
| **Corruption recovery** | None — `JSON.parse()` failure crashes `loadState()`. No fallback/repair. |
| **Migration plan** | Add schema version field `state._v` for future migration. Add try/catch with fallback to default state. |

**Risk:** Medium — single point of failure. If corrupted, user loses all progress.

### 1.2 `prdkit_projects` — Project History (Legacy)
| Property | Value |
|----------|-------|
| **Purpose** | Local project history cache (up to 50 entries) |
| **Format** | JSON array of project objects |
| **Typical size** | ~50 KB max (50 entries × ~1KB each) |
| **Max entries** | 50 (capped in code) |
| **Active use?** | **DEPRECATED** — D1-backed API (`/api/history`) is primary |
| **Read by** | Legacy `loadProjectHistory()` fallback? |
| **Written by** | Legacy — was used before D1 integration |
| **Corruption recovery** | None |
| **Migration plan** | Remove on next major version. D1 is authoritative. |

**Risk:** Low — still written in some code paths (`saveProjectToHistory` syncs to D1, localStorage may be fallback).

### 1.3 `prdkit_analytics` — Analytics Events
| Property | Value |
|----------|-------|
| **Purpose** | Local analytics event buffer |
| **Format** | JSON object with event arrays |
| **Typical size** | ~100 KB (500 events) |
| **Max entries** | 500 per event type |
| **Read by** | `getAnalytics()`, `showBetaDashboard()` |
| **Written by** | `trackEvent()` on every user action |
| **Corruption recovery** | None — `getAnalytics()` handles parse errors with `try/catch` → returns `{}` |
| **Migration plan** | Could be moved to D1 for cross-device analytics. Currently local-only. |

**Risk:** Low-medium — parse errors handled gracefully. Size is bounded (500 events per type).

### 1.4 `prdkit_unknown` — Unknown Domain Tracking
| Property | Value |
|----------|-------|
| **Purpose** | Tracks unrecognized domain strings for analytics |
| **Format** | JSON array |
| **Typical size** | ~10 KB (100 entries) |
| **Max entries** | 100 |
| **Read by** | `getUnknownDomains()`, `showBetaDashboard()` |
| **Written by** | `trackUnknownDomain()` |
| **Corruption recovery** | None — returns empty array on parse failure |
| **Migration plan** | None needed — small, self-contained |

### 1.5 `prdkit_key_obf` — Obfuscated API Key
| Property | Value |
|----------|-------|
| **Purpose** | Stores user's AI provider API key in obfuscated form |
| **Format** | Base64-like obfuscation (reversible) |
| **Typical size** | ~1 KB |
| **Read by** | `KEY_STORE.get()` before every AI call |
| **Written by** | `KEY_STORE.set()` on settings save |
| **Corruption recovery** | None — `KEY_STORE.get()` returns `''` on bad decode |
| **Security** | **WARNING**: This is obfuscation, not encryption. Reversible. Data at rest in localStorage is accessible to any JS on the origin. |
| **Migration plan** | Move to D1-backed provider storage (already in progress — `saveNewProvider()` POSTs to `/api/providers`). HttpOnly cookie for session. |

**Risk:** HIGH (security). API key is stored in plaintext (obfuscated, but trivially reversible). Any XSS vulnerability exposes the key. D1 migration partially addresses this.

### 1.6 `prdkit_lang` — Language Preference
| Property | Value |
|----------|-------|
| **Purpose** | User's language preference |
| **Format** | Plain string (e.g., `'id'`, `'en'`) |
| **Typical size** | ~100 B |
| **Read by** | Language toggle |
| **Written by** | Language switch |
| **Corruption recovery** | Falls back to `'id'` |
| **Migration plan** | None needed |

### 1.7 `prdkit_onboarded` — Onboarding Flag
| Property | Value |
|----------|-------|
| **Purpose** | Tracks whether onboarding has been dismissed |
| **Format** | Plain string (`'true'` or absent) |
| **Typical size** | ~10 B |
| **Read by** | Onboarding overlay check |
| **Written by** | `dismissOnboarding()` |
| **Corruption recovery** | Absence means "not onboarded" — safe |
| **Migration plan** | None needed |

---

## 2. D1 Database Tables (Cloudflare D1 via Worker)

The app uses a Cloudflare Worker with D1 database for persistence. Tables deduced from API endpoints:

### 2.1 `users` Table
| Property | Value |
|----------|-------|
| **Purpose** | User accounts (OAuth-linked) |
| **Schema** | Not documented in client code. Likely: `id`, `email`, `name`, `avatar`, `created_at` |
| **Accessed via** | Auth endpoints (`/api/auth/*`) |
| **Written by** | OAuth callback handler on Worker |
| **Read by** | Auth check, settings |

### 2.2 `settings` Table (or `ai_config`)
| Property | Value |
|----------|-------|
| **Purpose** | Per-user AI provider configuration |
| **Likely schema** | `user_id`, `provider`, `model`, `api_key` (encrypted), `base_url`, `created_at` |
| **Accessed via** | `GET/POST /api/providers`, `GET /api/config` |
| **Written by** | `saveNewProvider()`, `simpanProvider()` |
| **Read by** | `loadSavedProvidersFromD1()`, `saveAIConfigToWorker()` |
| **Note** | API keys stored here should be server-side encrypted |

### 2.3 `auth_states` Table
| Property | Value |
|----------|-------|
| **Purpose** | OAuth state parameter validation |
| **Likely schema** | `state`, `provider`, `created_at` |
| **Accessed via** | OAuth flow (transient — TTL of minutes) |

### 2.4 `project_history` Table
| Property | Value |
|----------|-------|
| **Purpose** | User's saved project history |
| **Likely schema** | `id`, `user_id`, `name`, `model`, `tech` (JSON), `extras` (JSON), `artifacts` (JSON), `versions` (JSON), `chatHistory` (JSON), `created_at` |
| **Accessed via** | `GET/POST/DELETE /api/history` |
| **Written by** | `saveProjectToHistory()` |
| **Read by** | `loadProjectHistory()`, `continueProject()` |
| **Max entries** | Not specified in client — likely unbounded per user |

---

## 3. Cookies

### 3.1 Auth Token (JWT)
| Property | Value |
|----------|-------|
| **Name** | Inferred — authentication cookie from Cloudflare Worker |
| **Type** | JWT (HttpOnly, Secure, SameSite) |
| **Purpose** | Authenticates API requests to Worker |
| **Set by** | OAuth callback on Worker |
| **Read by** | Worker middleware (server-side only) |
| **Client access** | **HttpOnly** — not accessible from JS |
| **Refresh** | Managed by Worker (likely token rotation) |

---

## 4. Session Storage

| Key | Status |
|-----|--------|
| **sessionStorage** | **Not used** — all ephemeral data stored in `state` object |

---

## 5. Cross-Storage Data Flow

```
User Action
    ↓
state object (in-memory)
    ↓
saveState() → localStorage.prdkit_state (persistence)
    ↓
saveProjectToHistory() → D1 /api/history (server-side)
    ↓
KEY_STORE.set() → localStorage.prdkit_key_obf (API key)
    ↓
saveAIConfigToWorker() → D1 /api/config (server-side)
```

**Dual-write pattern:** State is written to both localStorage AND D1 for most operations. This creates eventual consistency challenges — a write to localStorage might succeed while the D1 write fails, or vice versa.

---

## 6. Corruption Recovery Analysis

| Key | Has Recovery? | Recovery Behavior |
|-----|---------------|-------------------|
| `prdkit_state` | **NO** | `JSON.parse()` in `loadState()` has no try/catch — failure = blank app |
| `prdkit_projects` | Partial | `try/catch` in legacy loader → empty array |
| `prdkit_analytics` | Yes | `try/catch` in `getAnalytics()` → empty object `{}` |
| `prdkit_unknown` | Yes | `try/catch` → empty array `[]` |
| `prdkit_key_obf` | Partial | `KEY_STORE.get()` returns `''` on failure |
| `prdkit_lang` | Yes | Falls back to `'id'` |
| `prdkit_onboarded` | Yes | Absence = not onboarded (shows again) |

**Critical gap:** `prdkit_state` has no corruption recovery. If this key is corrupted (e.g., partial write during browser crash), the entire app fails silently.

---

## 7. Migration Plan

### Short-term (Next Update)
1. **Add `try/catch` to `loadState()`** — fallback to default state if `JSON.parse` fails
2. **Add schema version `state._v = 1`** — enable future migrations
3. **Cap `chatHistory`** — add max 100 entries (or 50), trim oldest on new addition
4. **Clean up `prdkit_projects`** — stop writing, clear on load if D1 integration is stable

### Medium-term
1. **Move API key to D1-only** — `KEY_STORE` should become a server-side proxy, not localStorage
2. **Add state migration function** — `migrateState(oldVersion)` for breaking changes
3. **Add storage quota monitoring** — warn user when approaching 5MB limit
4. **Add periodic D1 sync** — for offline resilience with eventual consistency

### Long-term
1. **Encrypt `prdkit_key_obf`** — use Web Crypto API (subtle.encrypt) instead of Base64 obfuscation
2. **Move analytics to D1** — for cross-device analytics
3. **Consider IndexedDB** — for larger artifacts and offline-first architecture

---

## 8. Risk Summary

| Risk | Severity | Impact |
|------|----------|--------|
| API key in localStorage (obfuscated, not encrypted) | **CRITICAL** | XSS → full API key compromise |
| `prdkit_state` has no corruption recovery | **HIGH** | Single corrupted write → total app failure |
| Chat history unbounded growth | **MEDIUM** | Could balloon to 500KB+ |
| Dual-write consistency (localStorage + D1) | **MEDIUM** | State drift between client and server |
| No state schema versioning | **MEDIUM** | Silent failures on structure changes |
| `prdkit_projects` legacy key bloat | **LOW** | Orphaned data, ~50KB |
| No storage quota monitoring | **LOW** | User hits 5MB limit without warning |
| No encryption at rest (D1 API key storage) | **MEDIUM** | Depends on Worker implementation (not visible in client code) |
