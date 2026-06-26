# Report 71: HTML Forensic Audit
**File:** index.html (3665 lines, 127KB)
**Date:** 2026-06-22
**Scope:** Complete audit of all pages/sections, event handlers, state dependencies, visibility conditions, responsive behavior, and issues.

---

## 1. HOME PAGE (id=page-home)

### Sections
| Section | Selector | Purpose |
|---------|----------|---------|
| Topbar | `.home-topbar` | Sticky header with brand, settings gear, login state |
| Hero | `.home-hero` | Split layout: left=title/desc/CTA, right=code window |
| Quick Templates | `.home-templates` | 4-column grid of domain template cards |
| Recent Projects | `#projectHomeHistory` | History list or empty state |
| Footer/Byline | `.home-byline` | Brand attribution with founder photo/initials |

### Event Handlers
| Element | Handler | Trigger |
|---------|---------|---------|
| `.home-template-card` (×8-12) | `onclick="useTemplate('delivery')"` etc. | Click on template card |
| `.home-hero-actions button[onclick*='Buat Baru']` | `gotoSetup()` | "Buat Baru" CTA button |
| `.home-settings` (gear icon) | `openSettings()` | Click settings gear |
| `.home-byline` / founder area | `onclick="onboarding()"` (implicit) | Click founder area |
| History cards (dynamic) | `onclick="continueProject('${id}')"` | Click project card |
| History card delete button | `onclick="event.stopPropagation();deleteProject('${id}')"` | Click trash icon |

### State Dependencies
| State Field | Read by | Relevant Section |
|-------------|---------|-----------------|
| `state.user` | Auth check; if null, `authGate` shown, home hidden | Topbar login state |
| `state.idea` | Used by `useTemplate()` to pre-fill idea field | Template cards |
| `state.aiProvider` | Checked by `renderRecentProjects()` | History section |
| Project history (D1 API) | `loadProjectHistory()` → `renderProjectHistory()` | Recent projects |

### Visibility Conditions
| Condition | Element | Rule |
|-----------|---------|------|
| Not logged in | `.page-home` | Display: none (authGate shown instead) |
| No history | `#historyEmpty` | Display: block |
| Has history | `#historyEmpty` | Display: none |
| Has history | `#projectHomeHistoryList` | Populated with cards |
| Loading history | `#projectHomeHistory` | Rendered async, no loading spinner (gap) |

### Responsive Behavior
| Breakpoint | Layout Change |
|------------|---------------|
| Default | Hero split (50/50), 4-column template grid, padding 64px |
| 900px | `@media (max-width:900px)` — stack hero, smaller padding |
| 768px | Template grid collapses, padding reduced |
| 600px | Single column, padding 24px |
| 480px | Compact layout, smaller fonts |

### Issues
- **Minor:** No loading skeleton for history cards — content jumps when async load completes.
- **Minor:** Template grid has no loading state if DOMAIN_PACKS fails to load.
- **Observation:** `home-code-window` is decorative only — no interactivity.

---

## 2. SETUP PAGE (id=page-setup)

### Sections
| Section | Selector | Purpose |
|---------|----------|---------|
| Product name | `#productName` (input) | Text input for product name |
| Category grid | `.category-grid` | 2×N grid of product categories |
| Subcategory | `.subcategory-area` | Shown after category selection |
| Category chips | `.category-chips` | Multi-select chips for subcategories |
| Go to wizard | `#goToWizardBtn` | Proceed to wizard step 1 |

### Event Handlers
| Element | Handler | Trigger |
|---------|---------|---------|
| Category card | `onclick="selectCategory('delivery')"` | Click category card |
| Subcategory chip | `onclick="toggleSubcategory(...)"` | Click chip |
| `#goToWizardBtn` | `onclick="goToWizard()"` | Click proceed button |

### State Dependencies
| Field | Written By | Purpose |
|-------|-----------|---------|
| `state.productName` | `goToWizard()` | Saved on proceed |
| `state.productCategory` | `selectCategory()` | Selected category |
| `state.productCategoryParent` | `goToWizard()` | Derived from category |
| `state.productType` | `selectCategory()` or default | 'web'/'mobile'/'hybrid' |

### Visibility Conditions
| Condition | Element | Rule |
|-----------|---------|------|
| Category selected | Subcategory area | display: block (JS toggles) |
| No category selected | `#goToWizardBtn` | Disabled (via JS) |
| Category grid empty | Grid itself | Hidden until JS fills it |

### Issues
- **Critical:** Category grid is entirely populated by JS (`renderCategories()`). If JS fails, the page is non-functional with no fallback.
- **Minor:** No loading state for category grid.
- **Observation:** Product name has no validation beyond `trim()` check in `goToWizard()`.

---

## 3. WIZARD PAGE (id=page-wizard)

### Sections
| Section | Selector | Purpose |
|---------|----------|---------|
| Progress bar | `.wizard-progress` | 4-step indicator |
| Step container | `#wizardContent` | Dynamic content per step |
| Step 1: Idea | `#wizardStep1` | Idea input + reference + AI suggestions |
| Step 2: Tech | `#wizardStep2` | Tech stack selection |
| Step 3: Features | `#wizardStep3` | Feature selection, extras |
| Step 4: Survey | `#wizardStep4` | Dynamic survey questions |
| Navigation buttons | `#wizardPrev`, `#wizardNext`, `#wizardGenerate` | Step nav |

### Event Handlers
| Element | Handler | Trigger |
|---------|---------|---------|
| `#wizardNext` | `nextWizardStep()` | Next step |
| `#wizardPrev` | `prevWizardStep()` | Previous step |
| `#wizardGenerate` | `generateBlueprint()` | Generate final output |
| AI suggestion chips | `onclick="applySuggestion(...)"` | Click suggestion |
| Feature toggle | `onclick="toggleFeature(...)"` | Click feature card |
| Extra option | `onclick="toggleExtra(...)"` | Click extra card |
| Survey answer chips | `onclick="answerSurvey(...)"` | Click answer |

### State Dependencies
| Field | Written By | Read By |
|-------|-----------|---------|
| `state.step` | `nextWizardStep()`, `prevWizardStep()` | `renderWizardStep()` |
| `state.idea` | Step 1 input | Step 3, generate |
| `state.reference` | Step 1 input | generate |
| `state.tech` | Step 2 selection | createArtifacts |
| `state.extras` | Step 3 toggles | createArtifacts |
| `state.answers` | Step 4 survey | createArtifacts |
| `state.surveyQ` | Survey navigation | renderSurvey |
| `state.surveyTotal` | `initSurvey()` | renderSurvey |

### Visibility Conditions
| Condition | Element | Rule |
|-----------|---------|------|
| Step N active | Step N | display: block (others: none) |
| Step === 1 | `#wizardPrev` | Hidden (no going back from start) |
| Step === 4 | `#wizardNext` | Hidden, replaced by `#wizardGenerate` |
| AI not configured | AI suggestion area | Shows "Configure AI" prompt |

### Responsive
- Steps collapse to single column at <768px
- Feature chips stack vertically at <480px
- Progress bar shrinks font-size

### Issues
- **Medium:** Step 1 AI suggestions only work if AI provider is configured. No graceful degradation — user sees an empty "Suggestions" section.
- **Minor:** Survey questions are entirely dynamic — no SSR fallback.
- **Observation:** `wizardStep` render function is large (~200 lines) — potential refactor target.

---

## 4. RESULT PAGE (id=page-result)

### Sections
| Section | Selector | Purpose |
|---------|----------|---------|
| Topbar | `.result-topbar` | Back button, project name, actions |
| Tabs | `#resultTabs` | Tab navigation (overview, artifacts, documents, visual, export) |
| Tab content | `#resultTabOverview`, `#resultTabArtifacts`, etc. | Tab panels |
| Feedback bar | `#feedbackBar` | Rating stars + category chips |
| Chat area | `#chatMessages` | Revision chat with AI |
| Version switcher | `#versionTabs` | Version history tabs |

### Event Handlers
| Element | Handler | Trigger |
|---------|---------|---------|
| Tab items | `onclick="switchResultTab('overview')"` etc. | Click tab |
| Download buttons | `onclick="downloadFile(...)"` | Click download |
| Copy buttons | `onclick="navigator.clipboard.writeText(...)"` | Click copy |
| Feedback stars | `.fb-star` | Click star |
| Feedback categories | `.fb-cat` | Click category |
| Submit feedback | `#feedbackSubmitBtn` | Click submit |
| Send revision | `#sendRevisionBtn` | Click send |
| Version tab | `onclick="switchVersion(...)"` | Click version |

### State Dependencies
| Field | Read By |
|-------|---------|
| `state.artifacts` | renderArtifacts, tab content |
| `state.versions` | version switch, render |
| `state.currentArtifact` | artifact selection |
| `state.currentVersion` | version switching |
| `state.chatHistory` | revision chat |

### Visibility Conditions
| Condition | Element | Rule |
|-----------|---------|------|
| Tab selected | Corresponding content panel | display: block |
| No artifacts | Artifact tab | Empty state message |
| First visit | Feedback bar | display: none initially, shown after timeout |
| Feedback submitted | Feedback bar | Hidden after submission + 3s delay |

### Issues
- **Medium:** 18+ artifact tabs historically created (being addressed in update). Current version shows 5 main tabs.
- **Minor:** Feedback bar shows even if user didn't generate anything.
- **Observation:** Version switching re-renders entire content — no caching.

---

## 5. AUTH GATE (id=authGate)

| Item | Detail |
|------|--------|
| Selector | `#authGate` |
| Event Handlers | Login button → OAuth flow |
| State Dep | `state.user` (null = shown) |
| Visibility | display:none when `state.user` is set |
| Issues | Entire app hidden if auth fails — no offline/guest mode |

---

## 6. SETTINGS MODAL (id=settingsModal)

| Item | Detail |
|------|--------|
| Selector | `#settingsModal` |
| Event Handlers | Provider select, API key verify, save/delete |
| State Dep | `state.aiProvider`, `state.aiModel`, `KEY_STORE` |
| Visibility | `.open` class toggled by `openSettings()`/`closeSettings()` |
| Two Flows | Saved providers list (initial view) → Add provider form |
| Issues | API key visible in DOM until `toggleApiKeyVisibility()` — not great security practice (but obfuscated in storage) |

---

## 7. DOCS MODAL (id=docsModal)

| Item | Detail |
|------|--------|
| Selector | `#docsModal` |
| Event Handlers | Close button |
| State Dep | None |
| Visibility | Toggled by `openDocs()` |
| Issues | No issues — simple, self-contained |

---

## 8. SIDEBAR (id=sidebar)

| Item | Detail |
|------|--------|
| Selector | `#sidebar` |
| Event Handlers | `onclick="navigateTo('home')"` etc. on each item |
| State Dep | Current page for active highlighting |
| Visibility | Toggled by `toggleSidebar()` — fixed left panel |
| Issues | display:none/flex toggle — no animation |

---

## 9. HISTORY PANEL (id=historyPanel)

| Item | Detail |
|------|--------|
| Selector | `#historyPanel` + `#historyPanelOverlay` |
| Event Handlers | Card click → `continueProjectHistory()`, delete button |
| State Dep | D1 project history |
| Visibility | Right slide-in, toggled by `toggleHistory()` |
| Issues | Same as home history — no loading skeleton |

---

## 10. ONBOARDING CARD (id=onboardingCard)

| Item | Detail |
|------|--------|
| Selector | `.onboarding-overlay` + `.onboarding-card` |
| Event Handlers | Dismiss button → `dismissOnboarding()` |
| State Dep | `localStorage.getItem('prdkit_onboarded')` |
| Visibility | Shown only on first visit (no `prdkit_onboarded` key) |
| Issues | Non-blocking overlay — can be dismissed easily |

---

## Summary of Findings

| Metric | Value |
|--------|-------|
| Total pages/sections audited | 10 (home, setup, wizard, result, auth, settings, docs, sidebar, history, onboarding) |
| Unique event handlers | ~30+ (onclick, onchange, oninput) |
| State dependencies per page | 1-5 fields each (total ~20 state fields touched) |
| Responsive breakpoints in HTML | 3 (900px, 768px, 600px, 480px — from CSS) |
| Critical issues | 1 (JS-dependent category grid in setup) |
| Medium issues | 3 (no loading states, AI-optional feature, large tab count) |
| Minor issues | 4 (no skeletons, no SSR fallback, decorative-only components) |
