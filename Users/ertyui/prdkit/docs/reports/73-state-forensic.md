# Report 73: State Object Forensic Audit
**File:** app.js — state object analysis
**Date:** 2026-06-22
**Scope:** All fields written to `state`, their readers, persistence, survival across sessions, corruption risks.

---

## Field Inventory

### 1. `state.productName`
| Property | Value |
|----------|-------|
| **Written by** | `goToWizard()` — reads from `#productName` input |
| **Read by** | `createArtifacts()` (prompt building), `renderRecentProjects()`, `continueProject()`, `saveProjectToHistory()`, `simpanPengaturan()`, download functions |
| **Persisted?** | Yes — `saveState()` serializes to `prdkit_state` in localStorage |
| **Survives refresh?** | Yes — restored from `prdkit_state` on load |
| **Survives restore?** | Yes — unless project restore path fails |
| **Potential corruption** | Empty string if no input or DOM fails to provide value. No max-length validation. Could contain XSS if `escapeHtml()` is skipped downstream. |

### 2. `state.productCategory`
| Property | Value |
|----------|-------|
| **Written by** | `selectCategory()` — from category card click |
| **Read by** | `goToWizard()` (passed to wizard), category auto-selection |
| **Persisted?** | Yes — in `prdkit_state` |
| **Survives refresh?** | Yes |
| **Survives restore?** | Not explicitly restored on `continueProject()` |
| **Potential corruption** | Could be stale if `DOMAIN_PACKS` structure changes between sessions |

### 3. `state.productCategoryParent`
| Property | Value |
|----------|-------|
| **Written by** | `goToWizard()` |
| **Read by** | `getDomain()` (domain inference) |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | No — not included in `continueProject()` restore |
| **Potential corruption** | Slight drift risk if domain mapping changes |

### 4. `state.idea`
| Property | Value |
|----------|-------|
| **Written by** | Wizard step 1 input (`renderWizardStep()` collects from `#ideaInput`) |
| **Read by** | `createArtifacts()` (prompt), `renderRecentProjects()`, domain inference |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Explicitly cleared to `''` on `continueProject()` — **intentional** (user re-enters idea) |
| **Potential corruption** | Cleared on project restore — user loses original idea text. No max-length. |

### 5. `state.reference`
| Property | Value |
|----------|-------|
| **Written by** | Wizard step 1 input |
| **Read by** | `createArtifacts()` (prompt context) |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | No — not restored |

### 6. `state.step`
| Property | Value |
|----------|-------|
| **Written by** | `nextWizardStep()`, `prevWizardStep()`, `continueProject()` |
| **Read by** | `renderWizardStep()`, progress bar |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Reset to `1` on `continueProject()` |
| **Potential corruption** | Could be out of bounds (not 1-4) if restore path is indirect |

### 7. `state.tech`
| Property | Value |
|----------|-------|
| **Written by** | Wizard step 2 — tech stack selection (frontend, backend, database, deployment) |
| **Read by** | `createArtifacts()` (prompt), `buildTechStack()` |
| **Persisted?** | Yes (objects serialize to JSON) |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — deep-copied via `{ ...state.tech }` |
| **Potential corruption** | Object structure — if fields are added/removed, old saves lose data |

### 8. `state.extras`
| Property | Value |
|----------|-------|
| **Written by** | Wizard step 3 — `toggleExtra()` (array of strings) |
| **Read by** | `createArtifacts()` (auth, payment, AI decisions) |
| **Persisted?** | Yes (array) |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — spread-copied |
| **Potential corruption** | Array mutation — strings must match `EXTRA_OPTIONS` keys exactly |

### 9. `state.answers`
| Property | Value |
|----------|-------|
| **Written by** | Survey step 4 — `answerSurvey()` (key-value pairs) |
| **Read by** | `createArtifacts()` via `getAnswer()`, `renderSurvey()` |
| **Persisted?** | Yes (object) |
| **Survives refresh?** | Yes |
| **Survives restore?** | Cleared to `{}` on `continueProject()` |
| **Potential corruption** | Key name mismatch if survey questions change between versions |

### 10. `state.surveyQ`
| Property | Value |
|----------|-------|
| **Written by** | Survey navigation — `answerSurvey()` increments |
| **Read by** | `renderSurvey()` |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Not explicitly restored |
| **Potential corruption** | Could exceed `surveyTotal` |

### 11. `state.surveyTotal`
| Property | Value |
|----------|-------|
| **Written by** | `initSurvey()` — computed from survey questions array |
| **Read by** | `renderSurvey()`, progress indicator |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Not explicitly restored |
| **Potential corruption** | Stale if survey questions change |

### 12. `state.artifacts`
| Property | Value |
|----------|-------|
| **Written by** | `createArtifacts()` — array of `{ id, label, content, ext }` objects |
| **Read by** | `renderArtifacts()`, `renderPreview()`, `renderDocumentsTab()`, download functions, exports |
| **Persisted?** | Yes — deep-cloned via `JSON.parse(JSON.stringify(...))` |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — deep-cloned |
| **Potential corruption** | **HIGH RISK**: Content can be very large (50KB+ for PRD+prompt). Exceeds localStorage 5MB quota? Unlikely per single artifact but cumulative could be. JSON parse errors if content has unescaped characters. |

### 13. `state.versions`
| Property | Value |
|----------|-------|
| **Written by** | `createArtifacts()` (initial v1), `sendRevision()` (new versions) |
| **Read by** | Version switching, history rendering |
| **Persisted?** | Yes — deep-cloned |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — deep-cloned |
| **Potential corruption** | Multiple versions with large content → localStorage pressure. Deep-clone of large objects is slow. |

### 14. `state.currentArtifact`
| Property | Value |
|----------|-------|
| **Written by** | `selectArtifact()` |
| **Read by** | `renderArtifacts()`, download functions |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — from project |
| **Potential corruption** | Index out of bounds if `artifacts` changes shape |

### 15. `state.currentVersion`
| Property | Value |
|----------|-------|
| **Written by** | `switchVersion()` |
| **Read by** | `renderVersionContent()` |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes |
| **Potential corruption** | Index out of bounds |

### 16. `state.chatHistory`
| Property | Value |
|----------|-------|
| **Written by** | `sendRevision()` — array of `{ role, content }` |
| **Read by** | `renderChatMessages()` |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — spread-copied |
| **Potential corruption** | **HIGH RISK**: Can grow unbounded with every revision. No max size enforcement. Could exceed localStorage quota. |

### 17. `state.aiProvider`
| Property | Value |
|----------|-------|
| **Written by** | `saveSettings()`, `selectProvider()`, `simpanPengaturan()` |
| **Read by** | `callAI()`, status indicators |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — from localStorage |
| **Potential corruption** | Name mismatch if PROVIDER_LIST changes. Empty string if not configured. |

### 18. `state.aiModel`
| Property | Value |
|----------|-------|
| **Written by** | `saveSettings()`, `selectProvider()` |
| **Read by** | `callAI()`, status indicators |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes |
| **Potential corruption** | Model string mismatch if provider removes model. Empty string allowed. |

### 19. `state.baseUrl`
| Property | Value |
|----------|-------|
| **Written by** | `saveSettings()`, `selectProvider()` |
| **Read by** | `callAI()` — passed in request config |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes |
| **Potential corruption** | Malformed URL → AI call fails silently. No URL validation on save. |

### 20. `state.mode`
| Property | Value |
|----------|-------|
| **Written by** | `applyTheme()` |
| **Read by** | `applyTheme()` (sets `document.body.dataset.mode`) |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Value** | Always `'dark'` — no light mode toggle available |
| **Potential corruption** | Low — single string, hardcoded to 'dark' |

### 21. `state.user`
| Property | Value |
|----------|-------|
| **Written by** | `checkAuth()` — after OAuth login completes |
| **Read by** | Auth gate logic, settings access check |
| **Persisted?** | Yes — but via `prdkit_state` (not separately) |
| **Survives refresh?** | Yes — restored from state |
| **Survives restore?** | No — cleared on project restore (obviously) |
| **Potential corruption** | Stale user info if token expires but state persists. OAuth token managed separately (cookie). |

### 22. `state._projectId`
| Property | Value |
|----------|-------|
| **Written by** | `saveProjectToHistory()` — generated as `Date.now().toString(36) + Math.random()` |
| **Read by** | `continueProject()`, `saveProjectToHistory()` |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes — primary key for history lookup |
| **Potential corruption** | Low — unique generation. Collision risk is astronomically low. |

### 23. `state._engineTabActive`
| Property | Value |
|----------|-------|
| **Written by** | `selectEngineTab()` |
| **Read by** | Engine tab rendering |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | Yes |
| **Potential corruption** | Low — string tab identifier |

### 24. `state.productType`
| Property | Value |
|----------|-------|
| **Written by** | Likely `selectCategory()` or `goToWizard()` — values: `'web'`, `'mobile'`, `'hybrid'` |
| **Read by** | `createArtifacts()` (prompt) |
| **Persisted?** | Yes |
| **Survives refresh?** | Yes |
| **Survives restore?** | No — not explicitly in `continueProject()` |
| **Potential corruption** | Could be undefined if user skips step. Defaults used in prompt. |

---

## Legacy / Removed Fields

| Field | Status | Notes |
|-------|--------|-------|
| `state.apiKey` | **REMOVED** | Replaced by `KEY_STORE` (obfuscated localStorage key `prdkit_key_obf`) |
| `state.navigate` | Removed | Replaced by `PRDKitRouter` |

---

## localStorage Persistence Summary

| Aspect | Detail |
|--------|--------|
| **Storage key** | `prdkit_state` |
| **Serialize** | `JSON.stringify(state)` in `saveState()` |
| **Deserialize** | `JSON.parse()` on load |
| **Update frequency** | Every major action (step change, settings save, artifact generate, project save) |
| **Size estimate** | ~5-50KB typical. With large artifacts + versions + chat history, could exceed 200KB+ |
| **Quota risk** | localStorage is 5MB per origin. Multiple large artifacts + versions + chat history could approach limits |

---

## Corruption Risks (Ranked)

| Risk | Severity | Details |
|------|----------|---------|
| **Chat history unbounded growth** | HIGH | No max size on `chatHistory`. Each revision adds 2 entries. 100 revisions = ~50KB+ |
| **Artifact/version size** | MEDIUM | Deep-cloned large objects. Individual PRD+prompt can be 30-50KB. Multiple versions multiply this. |
| **Survey question drift** | MEDIUM | `answers` keys tied to survey definition. If survey changes, old `answers` are meaningless. |
| **Provider name mismatch** | MEDIUM | `aiProvider` is a display name string. If PROVIDER_LIST changes order or names, state references are orphaned. |
| **Stale `_projectId`** | LOW | Could reference a deleted D1 project. |
| **Index out of bounds** | LOW | `currentArtifact`, `currentVersion` could reference indices beyond array length after state manipulation. |
| **JSON parse failure** | LOW | If `prdkit_state` gets corrupted (rare), entire app fails to load. No fallback/repair mechanism. |

---

## Observations

1. **No schema versioning** — state has no `_version` field. Future changes to state shape could silently break old saves.
2. **No migration path** — if state structure changes, old localStorage data will be loaded with missing/extra fields.
3. **No size monitoring** — no warning when approaching localStorage quota limits.
4. **No validation on restore** — `continueProject()` restores fields without type-checking.
5. **`continueProject()` clears `idea` and `answers`** — this is intentional for re-entry but means the project name/domain is kept while the creative input is lost.
6. **Deep-clone performance** — `JSON.parse(JSON.stringify(x))` used in hot paths (artifact save, version save). On large objects this could cause frame drops.
7. **`state._projectId` uses `_` prefix** — convention for private/internal fields, but nothing enforces this.
