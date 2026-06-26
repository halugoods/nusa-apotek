# Report 72: CSS Forensic Audit
**File:** styles.css (3394 lines, 74KB) + inline `<style>` in index.html (~120 lines)
**Date:** 2026-06-22
**Scope:** Selector analysis, dead selectors, duplicate rules, breakpoints, z-index layering, inline styles, specificity, animation performance, risk areas.

---

## 1. Selector Count

| Category | Count |
|----------|-------|
| CSS rule blocks (opening `{`) | 541 |
| Unique class selectors (.class) | 333 |
| Unique ID selectors (#id) | 23 |
| Total selectors (estimated, with combinators) | ~620+ |
| Unique class selectors used in HTML+JS | ~771 (including JS-generated) |

**Note:** JS dynamically generates many class names (e.g., `history-card`, `overview-stat-card`, `provider-radio-item`) that are defined in styles.css but referenced only via string concatenation in `app.js`. These are not "dead" but are invisible to static HTML analysis.

---

## 2. Dead Selectors

### Classes defined in CSS but NOT used in HTML (static) or JS (static)
These classes may be:
- Legacy/residual from refactored features
- Dynamic classes added/removed via `classList.toggle()` (hard to detect statically)
- Reserved for future use

**Likely dead (no reference found anywhere in source):**
```
.ai-setting-input, .ai-setting-label, .ai-setting-row, .ai-setting-select,
.ai-setting-value, .ai-settings-badge, .ai-settings-body, .ai-settings-footer,
.ai-settings-header, .ai-settings-panel, .ai-settings-slider, .ai-settings-title,
.ai-settings-toggle, .ai-settings-toggle-slider, .api-key-row, .api-status,
.artifact-content, .badge-dot, .btn-danger, .btn-ghost, .btn-lg, .btn-primary,
.btn-sm, .chat-messages, .chat-msg, .chip-group, .closed, .cmt, .code-cursor,
.code-line, .code-preview, .code-preview-body, .code-preview-header,
.code-window-line-num, .confirm-modal, .confirm-modal-actions, .confirm-modal-content,
.confirm-modal-text, .confirm-modal-title, .container, .countdown, .custom-select,
.dashed-box, .detail-description, .detail-header, .detail-icon, .detail-label,
.detail-value, .domain-ai-badge, .domain-ai-icon, .domain-ai-row,
.domain-suggestion, .domain-suggestions, .drag-handle, .dropdown, .faq-item,
.feature-item, .filter-bar, .fixed-warning, .flash, .flex-center, .flow-item,
.form-error, .form-group, .form-hint, .form-input, .form-label, .form-select,
.form-textarea, .full-width, .glass-tab, .glass-tabs, .grid-2, .grid-3,
.grid-4, .group-hover, .grow, .header, .hidden, .highlight, .icon-btn,
.icon-left, .icon-right, .img-full, .inline-code, .input-group, .input-icon,
.insight-card, .kbd, .key, .label, .layout, .left, .link, .list-item,
.loading-dots, .loading-spinner, .logo, .m-0, .m-2, .m-4, .m-8, .main-content,
.mb-0, .mb-1, .mb-2, .mb-3, .mb-4, .mb-8, .menu-item, .mini-chart, .ml-auto,
.mobile-only, .modal-body, .modal-footer, .modal-header, .modal-overlay,
.modal-title, .mono, .mt-1, .mt-2, .mt-3, .mt-4, .mt-8, .multi-input,
.nav-item, .nav-link, .no-select, .note, .notification, .op-0, .op-50,
.overflow-auto, .p-0, .p-1, .p-2, .p-3, .p-4, .p-6, .p-8, .page-title,
.panel, .pill, .pill-lg, .pill-sm, .popover, .popover-arrow, .progress-circle,
.progress-fill, .progress-label, .progress-track, .pulse, .px-2, .px-3,
.px-4, .py-1, .py-2, .py-3, .questions-flow, .quick-action, .quote,
.radio-group, .rating, .recent-projects, .results-list, .right, .ripple,
.rounded, .row, .scroll-area, .scroll-x, .search-bar, .section, .section-desc,
.section-title, .select-all, .select-none, .separator, .shimmer, .shrink-0,
.sidebar-footer, .sidebar-header, .sidebar-icon, .sidebar-label, .sidebar-logo,
.sidebar-nav, .skeleton, .skeleton-line, .skeleton-shape, .skeleton-text,
.small, .sort-btn, .spacer, .spinner, .split-layout, .stack, .stat-card,
.stat-icon, .stat-label, .stat-value, .stats-grid, .status-badge, .status-dot,
.step-item, .step-label, .step-number, .sticky, .sub-text, .subtitle,
.svg-icon, .switch, .table, .tabs, .tag, .tag-input, .taskbar, .team-card,
.testimonial, .text-center, .text-left, .text-right, .textarea, .timeline,
.timeline-dot, .timeline-item, .toast-error, .toast-info, .toast-success,
.toast-warning, .toggle, .toolbar, .tooltip, .tooltip-arrow, .topbar,
.topic-card, .tr, .truncate, .w-full, .white-space-pre, .wizard-card,
.wizard-card-body, .wizard-card-icon, .wizard-card-title, .wizard-cards
```

**Estimated dead selector rate:** ~200 / 333 = **~60% dead selectors**

This is very high. Many are utility classes (`.m-0`, `.p-4`, `.flex-center`, `.text-center`) or generic component styles (`.btn-primary`, `.loading-spinner`, `.modal-overlay`, `.tooltip`) that were likely defined in anticipation of use but never actually referenced in the current code.

### IDs defined in CSS but not in HTML/JS
```
#aiExampleCards, #app
```
These 2 IDs are defined in CSS but not referenced in the current HTML or JS.

---

## 3. Duplicate Rules (Inline `<style>` vs `styles.css`)

The inline `<style>` block in index.html (~lines 11-130) contains:

| Rule | Inline `<style>` | In `styles.css`? |
|------|-------------------|------------------|
| `.page { display: none; }` | Yes | **Not found** |
| `.page.active { display: block; }` | Yes | **Not found** |
| `.page-enter` / `.page-exit` animations | Yes | **Not found** |
| `@keyframes pageEnter` / `pageExit` | Yes | **Not found** |
| `.page-home` styling | Yes | Yes (but inline has priority) |
| `.home-topbar` | Yes | Yes (DUPLICATE) |
| `.home-brand-area` | Yes | Yes (DUPLICATE) |
| All `.home-*` styles up to `.home-template-desc` | Yes | Yes (DUPLICATE) |

**Finding:** The inline `<style>` in index.html is largely a duplicate of the first 300 lines of styles.css. This means any change to `.home-*` styles must be made in TWO places — a maintenance hazard.

**Duplicate risk area:** `.home-hero`, `.home-topbar`, `.home-templates`, `.home-template-card`, `.home-code-window`, `.home-code-header`, `.home-code-body`, `.home-code-dot`, `.home-byline`, `.home-founder-photo`, `.home-founder-initials`, `.home-brand-name`, `.home-brand-sub`, `.home-settings`

---

## 4. Media Query Breakpoints

| Breakpoint | Line | Selectors Affected |
|------------|------|-------------------|
| `@media (max-width: 900px)` | 2850 | ~70 lines — `.home-hero`, home layout, padding/font reductions |
| `@media (max-width: 600px)` | 2921 | ~10 lines — topbar padding |
| `@media (max-width: 768px)` | 2930 | ~83 lines — team grid, section padding, wizard, sidebar, result, modals |
| `@media (max-width: 480px)` | 3013 | ~360 lines — compact views, home hero stack, smaller UI elements |

**Missing breakpoints:** No `min-width` queries, no landscape orientation handling, no print styles.

---

## 5. Z-Index Layers

| Value | Purpose | Location |
|-------|---------|----------|
| 0 | Glass panel pseudo-element background | .glass-panel::before |
| 1 | Glass panel content, skeleton shapes | .glass-panel-content, .skeleton-shape |
| 50 | Sticky elements (home-topbar, wizard-steps, result-topbar) | Lines 183, 842, 1368 |
| 100 | Toasts, floating elements | Line 1640 |
| 200 | Modals, onboarding overlay | Lines 2137, 3376 |
| 299 | Settings modal (below toast, above modal) | Line 2365 |
| 300 | Toast notifications | Line 2250 |
| 1100 | Mobile preview overlay | Line 1961 |
| 9999 | Loading interstitial | Line 73 |

**Conflict risk:** Z-index 299 (`.settings-modal`) and 300 (`.toast-container`) are adjacent — if a toast needs to appear over the settings modal, it works (toast = 300 > modal = 299). However, this is fragile:
- `onboarding-overlay` at 200 is BELOW `.settings-modal` at 299 — intentional? If both are open, settings would float above onboarding.
- Skip-link at 9999 vs mobile preview at 1100 — preview could be below the skip-link.

---

## 6. Inline Styles in app.js

| Category | Count | Examples |
|----------|-------|---------|
| Direct `.style.*` assignments | ~67 | `.style.display = 'none'`, `.style.opacity = '0.8'` |
| HTML string concatenation (innerHTML) | ~200+ | Style attributes in template literals |
| Dynamic class toggling | ~120+ | `.classList.add/remove/toggle` |
| Element creation with styles | ~50+ | `Object.assign(el.style, {...})` |

**Estimated total inline style operations:** ~437 throughout app.js (8215 lines)

**Risk areas:**
- Many inline styles could be moved to CSS classes (e.g., font-size, padding, color).
- Template literals with `style="display:block"`, `style="padding:32px"`, `style="color:var(--muted-dim)"` are scattered — hard to maintain.
- No centralized style constants or CSS-in-JS approach.

---

## 7. Specificity Issues

### Potential Conflicts
| Selector | Specificity | Conflict With |
|----------|-------------|---------------|
| `.page-home.active` (0,2,0) | vs | Inline `<style>` `.page-home.active` (same) — which wins depends on load order |
| `.home-template-card:hover` (0,2,1) | Could be overridden by inline styles on template cards created by JS |
| `.toast` (0,1,0) | Low specificity — could be overridden by `.container .toast` (0,2,0) if both exist |
| `button.action-btn` (0,1,1) | vs `.action-btn` alone — tag qualification adds specificity, hard to override |

### !important Usage
| Count | Context |
|-------|---------|
| Minimal | n/a — no `!important` found in CSS |
| Inline | n/a — some `style` attrs in JS template strings |

---

## 8. Animation Performance

### CSS Animations
| Animation | Type | Affects Layout? |
|-----------|------|----------------|
| `@keyframes pageEnter` (opacity + translateY) | Composite | No (transform + opacity) |
| `@keyframes pageExit` (opacity + translateY) | Composite | No |
| `.home-template-card:hover` (translateY) | Composite | No |
| `.glass-panel::before` (opacity) | Composite | No |
| `.toast` enter (slide-in) | Composite | No |
| Various `transition: all` | Layout + Paint | **Yes** — `transition: all` triggers paint on ALL properties |

### Performance Concerns
- **`transition: all`** is used in multiple places — this triggers repaints for every CSS property change. Replace with `transition: transform, opacity` where possible.
- `.home-code-header` has `transition: all var(--transition)` — ~200ms on all properties.
- No `will-change` hints, no `contain` property usage.
- No `transform: translateZ(0)` GPU acceleration hints.

---

## 9. Risk Areas

| Risk | Severity | Details |
|------|----------|---------|
| **Overflow in code window** | Medium | `.home-code-body` has `overflow-x: auto` but no max-height — long output could push layout |
| **Mobile overflow** | Low | `.page-home` has `min-height: 100vh` but no `overflow-x: hidden` — could cause horizontal scroll on very small devices |
| **Dark mode consistency** | Low | CSS variables use `--bg`, `--surface`, `--text` etc. for theming. No light mode support — `mode` is always `'dark'` |
| **Inline <style> duplication** | High | ~300 lines of CSS duplicated between `<style>` and styles.css — maintenance burden |
| **Dead selector bloat** | Medium | ~60% of selectors not referenced — adds page weight (~20KB of unused CSS) |
| **Z-index fragility** | Medium | Tight spacing between layers (299 vs 300 vs 9999) — easy to break |
| **No print stylesheet** | Low | Print would render with dark backgrounds and no page breaks |
| **Font loading** | Low | Google Fonts CDN required for Geist + JetBrains Mono — no local fallback |

---

## Summary

| Metric | Value |
|--------|-------|
| CSS file size | 74KB (3394 lines) + ~4KB inline |
| Selector count | 541 rule blocks, 333 unique class selectors |
| Dead selectors | ~200 (60% — very high) |
| Duplicate rules (inline vs external) | ~300 lines |
| Breakpoints | 4 (900px, 768px, 600px, 480px) |
| Z-index values | 9 distinct layers (0 to 9999) |
| Inline style operations in JS | ~437 |
| `!important` usage | None found |
| `transition: all` usage | Multiple — performance concern |
| Risk areas identified | 8 (1 high, 2 medium, 5 low) |
