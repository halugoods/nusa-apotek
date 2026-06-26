# Report 82: Accessibility Audit

**Files:** index.html, app.js, styles.css
**Date:** 2026-06-22

---

## Executive Summary

**Score: 2/10** — The application has no accessibility features whatsoever. It is unusable with screen readers, keyboard-only navigation is broken, and there are no accommodations for visual, motor, or cognitive impairments.

---

## 1. ARIA Attributes: FAIL (0/10)

**Zero ARIA attributes found across the entire codebase.**

| Required ARIA | Found | Count |
|---------------|-------|-------|
| `aria-label` | No | 0 |
| `aria-labelledby` | No | 0 |
| `aria-describedby` | No | 0 |
| `aria-hidden` | No | 0 |
| `aria-expanded` | No | 0 |
| `aria-current` | No | 0 |
| `aria-selected` | No | 0 |
| `aria-role` | No | 0 |
| `role` attributes | No | 0 |

**Impact:** Screen readers (JAWS, NVDA, VoiceOver) will have no semantic context for any interactive element. Buttons, tabs, modals, and navigation elements are entirely invisible to assistive technology.

---

## 2. Keyboard Navigation: FAIL (0/10)

### 2.1 No `tabindex` Management

- No explicit `tabindex` attributes in index.html
- Default tab order follows DOM order (which is the page layout order, not logical reading order)
- The wizard flow (step 1 → tech → survey → generate) has no keyboard navigation logic

### 2.2 No Keyboard Shortcuts

- No keyboard shortcuts defined
- No Escape key handler for closing modals (modal overlays only have `onclick="closeSettings()"` on overlay div — no keyboard handler)
- No Enter/Space key handling for custom interactive elements

### 2.3 No Focus Trapping in Modals

The settings modal (`#settingsModal`) and docs modal (`#docsModal`) do not trap focus:
- Tab key will move focus outside the modal to page elements behind it
- No focus management when modal opens/closes
- No close-on-Escape handler

**Example:** The settings modal (index.html:2541, app.js:7068) only closes via click on the X button or overlay. A keyboard user cannot close it with Escape.

### 2.4 No Skip-to-Content Link

No skip navigation link for keyboard users to bypass the top bar and sidebar.

---

## 3. Screen Reader Support: FAIL (0/10)

### 3.1 No Live Regions

- No `aria-live` regions for dynamic content updates
- Toast messages (`showToast()`, app.js:626) are not announced to screen readers
- Survey question transitions are not announced
- Artifact tab switches are not announced
- Status changes ("Generating...", "Done") are not announced

### 3.2 No Alternative Text

- SVG icons used throughout (via `iconSvg()`, app.js:123) have no accessible labels
- Buttons with only SVG icons (sidebar toggle, settings, close buttons) have no text alternatives
- The founder photo `<img>` elements have no `alt` attributes (index.html)

### 3.3 No Heading Hierarchy

- No proper `<h1>` through `<h6>` structure
- Headings are styled `<div>` elements with CSS classes only
- A screen reader navigating by headings would find no landmarks

### 3.4 No Landmarks

- No `<nav>`, `<main>`, `<aside>`, `<header>`, `<footer>` elements
- Everything is `<div>` and `<span>` based
- No `role="navigation"`, `role="main"`, etc.

---

## 4. Color and Contrast: PASS (partial)

### Strengths
- Dark theme with proper contrast ratios (white/light text on dark backgrounds)
- CSS custom properties define a consistent color scheme (`--text`, `--muted`, `--primary`, etc.)
- No instances of text-on-image that would fail contrast

### Weaknesses
- No high-contrast mode support
- No `prefers-reduced-motion` media query — all animations play even for users with vestibular disorders
- Success/error toasts rely solely on color (green/red) with no icon differentiation for colorblind users

---

## 5. Touch Targets: PASS (partial)

### Strengths
- Buttons have adequate size (36px+ in most cases)
- Cards in the template grid are large (tap-friendly)
- The survey chip selection targets are appropriately sized

### Weaknesses
- Some icon buttons (sidebar toggle, close buttons) are 24-28px, below the recommended 44px minimum
- Inline `onclick` spans (chips, tech cards) have no min-size CSS enforcement
- No `touch-action: manipulation` set to prevent 300ms delay on mobile

---

## 6. Semantic HTML: FAIL

The entire application uses `<div>` and `<span>` for all structural elements:
- No `<form>` elements (all input handling through JS)
- No `<button>` used consistently (some interactive elements are `<span>` with `onclick`)
- No `<label>` elements for form inputs
- No `<table>` for data tables (built as string-based HTML in JS)
- No `<ul>`/`<ol>` for lists

---

## 7. Dynamic Content: FAIL

### 7.1 Modals
- No focus management when opening (app.js:7068+)
- No Escape key handler
- No announcement to screen readers

### 7.2 Loading States
- "Generating..." text appears but is not in a live region
- No progress indicators with ARIA attributes

### 7.3 Error States
- Error toasts via `showToast()` (app.js:626) are visual only
- No inline error messages with `aria-describedby`
- No `aria-invalid` on invalid inputs

---

## Remediation Priority

| # | Fix | Effort | Impact |
|---|-----|--------|--------|
| 1 | Add `role="dialog"`, `aria-modal="true"`, Escape key, focus trap to modals | 2 hours | High |
| 2 | Add `aria-label` to all icon-only buttons | 1 hour | High |
| 3 | Add `alt` attributes to all images | 30 min | High |
| 4 | Add `aria-live="polite"` to toast container | 10 min | High |
| 5 | Add `prefers-reduced-motion` media query | 10 min | Medium |
| 6 | Replace `<div>` buttons with `<button>` elements | 2 hours | Medium |
| 7 | Add `aria-current="page"` to active nav items | 30 min | Medium |
| 8 | Add tabindex management to wizard flow | 4 hours | Medium |
| 9 | Add skip-to-content link | 30 min | Medium |
| 10 | Add `role` landmarks (nav, main, aside) | 1 hour | Medium |

**Score: 2/10 — Needs comprehensive rework.**
