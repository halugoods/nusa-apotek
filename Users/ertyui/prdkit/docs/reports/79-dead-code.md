# Report 79: Dead Code Analysis

**File:** app.js, styles.css, index.html
**Date:** 2026-06-22

---

## 1. Dead JavaScript Functions

### Functions defined but never called (no caller path found)

| Function | Location | Scope | Status |
|----------|----------|-------|--------|
| `clearProjects()` | app.js:4803 (inside `createArtifacts()`) | Local closure | **DEAD** — no HTML onclick, no JS call site |
| `getFeedbackStats()` | app.js:4754 (inside `createArtifacts()`) | Local closure | **DEAD** — not exposed via `window.*`, not called internally |
| `getAnalytics()` | app.js:4740 (inside `createArtifacts()`) | Local closure | **DEAD as called from showBetaDashboard** — not exposed globally; `showBetaDashboard()` (line 8189) calls it but it's out of scope → would throw ReferenceError at runtime |
| `getUnknownDomains()` | app.js:4747 (inside `createArtifacts()`) | Local closure | Same issue as `getAnalytics()` |
| `saveProject()` | app.js:4767 (inside `createArtifacts()`) | Local closure | **DEAD** — not exposed, not called internally |
| `loadProjects()` | app.js:4789 (inside `createArtifacts()`) | Local closure | **DEAD** — not exposed, not called internally |
| `deleteProject()` | app.js:4796 (inside `createArtifacts()`) | Local closure | **DEAD** — there's a separate global `deleteProject()` at line 7477; this inner one is shadowed |
| `restoreProject()` | app.js:4807 (inside `createArtifacts()`) | Local closure | **DEAD** — not exposed globally |
| `openProject()` | app.js:4849 (inside `createArtifacts()`) | Local closure | **DEAD** — called from inline onclick in `renderRecentProjects` but `renderRecentProjects` is also nested, so this works... but nothing outside the closure calls it |
| `dedupFeatures()` | app.js:4634 | Nested | **DEAD** — defined inside `createArtifacts()`, never called |
| `buildActorDesc()` | app.js:5256 | Nested | **DEAD** — defined but never called even within `createArtifacts` |

### Functions with scope / shadowing bugs

| Function | Issue |
|----------|-------|
| `trackEvent()` (line 4712) | Nested inside `createArtifacts()`, exposed via `window.trackEvent`. But a global `trackEvent()` also exists at line 653. When called from outside `createArtifacts()`, which one runs? The global one (line 653). The nested one is dead for external callers. |
| `trackUnknownDomain()` (line 4724) | Same shadowing issue — global at line 665, nested at line 4724. |
| `deleteProject()` (line 4796) | Inner function shadowed by global at line 7477. Inner one dead. |

### Functions from HTML onclick that work correctly (for reference)

These are correctly wired:
`expandIdea()` → HTML button onclick → app.js:929 ✓
`getRelativeTime()` → called by `renderRecentProjects()` and `renderResultHistory()` ✓
`selectEngineTab()` → called from `renderArtifacts` onclick → app.js:6339 ✓

### Functions only in backup, removed from main app.js

These exist in `backup01prdkit/app.js` but NOT in `docs/app.js`:
- `openRevisionChat()` — just shows toast
- `loadContoh()` — just shows toast
- `resetProject()` — reset logic

(These are cleanly removed, not dead.)

---

## 2. Duplicate Functions

| Function | First Definition | Second Definition | Impact |
|----------|-----------------|-------------------|--------|
| `showRandomTip()` | app.js:677 | app.js:699 | Second overwrites first. Lines 677-683 are dead code. |
| `dismissTip()` | app.js:685 | app.js:708 | Second overwrites first. Lines 685-688 are dead code. |
| `trackEvent()` | app.js:653 (global) | app.js:4712 (nested) | Global version (line 653) is what external callers use. |
| `trackUnknownDomain()` | app.js:665 (global) | app.js:4724 (nested) | Global version (line 665) is what external callers use. |

---

## 3. Dead Constants

| Constant | Location | Status |
|----------|----------|--------|
| `SURVEY_QUESTIONS` | app.js:535 | **DEAD** — set to empty array `[]`, comment says "Deprecated — adaptive survey used instead" |
| `ANALYTICS_KEY` | app.js:4709 | **DEAD (nested)** — inside `createArtifacts()`, only used by nested functions that are also dead |
| `UNKNOWN_KEY` | app.js:4710 | **DEAD (nested)** — same as above |
| `HISTORY_KEY` | app.js:4765 | **DEAD (nested)** — inside `createArtifacts()`, only used by inner save/load functions |

---

## 4. Dead CSS Selectors

**Total selectors in styles.css:** ~461

**Selectors NOT referenced in index.html or app.js** (estimated ~60-80 dead):

Examples of CSS classes defined in styles.css but never used in markup/JS:
- `.home-badge`, `.badge-dot` — no matching HTML
- `.founder-photo`, `.founder-photo-placeholder` — no matching HTML
- `.headline`, `.subheadline` — no matching HTML
- `.home-actions` — no matching HTML
- `.home-footer` — no matching HTML
- `.code-preview`, `.code-preview-header`, `.preview-dot`, `.code-line`, `.code-cursor` — no matching HTML
- `.templates-section`, `.template-grid`, `.template-card`, `.t-icon`, `.t-name`, `.t-desc` — no matching HTML
- `.project-history`, `.history-item` (styles.css:548) — no matching HTML (different from `.result-history-item`)
- `.nav-bar`, `.nav-brand`, `.nav-spacer`, `.nav-back` — no matching HTML
- `.setup-nav` — no matching HTML
- `.result-preview-header`, `.result-preview-content` — no matching HTML
- `.result-tab-indicator` — no matching HTML
- `.wizard-step`, `.wizard-step-active`, `.wizard-step-done`, `.wizard-step-number`, `.wizard-step-label` — no matching HTML
- `.result-pane`, `.result-pane-header`, `.result-pane-body`, `.result-pane-toolbar` — no matching HTML

**Estimated dead selectors:** ~70-90 (15-20% of total CSS)

---

## 5. Dead / Redundant HTML

| Element | Location | Status |
|---------|----------|--------|
| Many `id` attributes in static HTML that are never referenced by JS | Throughout index.html | **POTENTIALLY DEAD** — see full HTML forensic (report 71) |
| Review pages, settings panels hidden by default | index.html | These are SPA pages, intentionally hidden until navigated to — not dead |

---

## Summary

- **Dead JS functions:** ~12-15 (mostly nested inside `createArtifacts()` closure, never exposed or called)
- **Duplicate functions:** 4 pairs (first definition is dead)
- **Dead constants:** 4 (1 deprecated, 3 nested inside dead scope)
- **Dead CSS selectors:** ~70-90 of 461 total
- **Runtime bugs from dead/scope issues:** `showBetaDashboard()` calls out-of-scope `getAnalytics()` and `getUnknownDomains()` — will throw ReferenceError
