# PRDKit UI — Visual Design Requirements for GLM 5.2

## Product Overview

PRDKit is an AI-powered Product Blueprint Studio. Its goal is to help non-technical
founders (and technical ones) go from "I have an idea" to "I have a complete product
blueprint" — including PRD, database schema, API docs, types, and diagrams.

The user never needs to write PRDL code. They answer guided questions in a wizard,
and the system generates a PRDL blueprint internally, then compiles to all output
formats.

---

## Target Users

- **Primary:** Halu Goods (Mas Halu) — founder, non-expert in software architecture.
  Motivated by: speed, clarity, free options, and getting actionable outputs.
- **Secondary:** Other non-technical founders who need PRD + code scaffolding.

---

## Core UX Principle

**Wizard-first. Code-editor (PRDL) behind a power-user door.**

The wizard is the default experience. The PRDL code editor lives behind a toggle
or "Switch to Editor" button. Most users never need to see PRDL.

---

## Page Architecture

### 1. Welcome / Landing Page

**Purpose:** Hook user immediately. One action: start a new project.

Elements:
- Brand: "PRDKit by Halu Goods"
- Tagline: "From idea to blueprint. Tanpa bingung mulai dari mana."
- CTA: "Buat PRD Baru" (large, green neon)
- Secondary: "Lihat Contoh" (opens a sample PRD)
- Footer: clean, minimal

**Design notes:**
- Dark background with subtle green neon glow (Halu Goods brand)
- Single centered column. No sidebar, no nav.
- Gradient background: dark base + green/teal radial glow (like prdkit.halugoods.com)
- Typography: Inter, bold headline, clean body
- Green accent: `#00e08f`, Dark bg: `#030605`

---

### 2. Wizard Flow (Steps 1-4)

#### Step Layout (shared across all steps)

Elements:
- **Top Bar**: step indicators (1/2/3/4) + project title (editable)
- **Main Content**: centered card/panel with the current step's form
- **Navigation**: "Kembali" (left) and "Lanjut" (right) buttons
- **Bottom**: no dock yet (reserved for future output artifacts)

Step indicator style:
- Circles with numbers, connected by a line
- Active: filled green `#00e08f`
- Completed: green checkmark
- Inactive: muted outline
- Labels below: "Ide", "Teknologi", "Survey", "Blueprint"

---

#### Step 1 — Ide

**Purpose:** User describes their product idea in natural language.

Questions:
1. What is your product called? (text input, required)
2. Describe your idea in 2-3 sentences (textarea, 20-500 chars)
3. What kind of product is this? (select/radio)
   - Options: Web App, Mobile App, API / Backend, Full-Stack, Microservice, Desktop App, Lainnya
4. (Optional) Any reference products / inspiration? (text input, free text)

**AI Behavior:**
- If user types a brief idea, show a "Kembangkan Ide" button that expands it with AI
- Show 3 example ideas below the form (clickable to fill the form)

**Design notes:**
- Large textarea, monospace or clean font
- Character counter (min 20, max 10,000)
- Subtle example cards below the form

---

#### Step 2 — Teknologi

**Purpose:** User chooses their tech stack. Every option includes a free-tier
recommendation.

Categories:

**Frontend:**
- Biarkan AI pilih (recommended for non-tech users)
- Next.js (free: Vercel Hobby)
- React + Vite (free: Vercel/Netlify)
- Vue + Vite, SvelteKit, Astro (free options)
- Flutter (for mobile)
- Expo (React Native)
- Electron (desktop)

**Backend:**
- Biarkan AI pilih
- Node.js + Hono (free: any)
- NestJS, Express, FastAPI
- Supabase (free: 500MB DB, auth, storage)
- Firebase (free: Spark plan)
- Laravel, Rails, Go

**Database:**
- Biarkan AI pilih
- PostgreSQL (free: Supabase, Neon, Railway)
- SQLite (free: zero-infra, file-based)
- MySQL, MongoDB, Turso, Redis

**Deployment:**
- Biarkan AI pilih
- Vercel (free Hobby), Netlify (free), Cloudflare Pages (free)
- Railway (free $5/mo), Fly.io, Render

**Extras (multi-select chips):**
- Auth (Login & role)
- Payment / Subscription
- File upload / Storage
- Admin dashboard
- Realtime updates
- Email / Push notification
- Analytics
- AI feature
- Mobile-first
- Import/Export

**Free-tier badge:** each option that has a generous free tier gets a small
"Gratis ✓" badge in green.

**Design notes:**
- Grid layout: 2 columns per category
- Each option is a clickable card with icon (if available) + label + free badge
- Selected cards have green border/glow
- "Biarkan AI pilih" is the default for all categories
- Collapsible categories

---

#### Step 3 — Survey

**Purpose:** Collect domain-specific requirements through questions.

Questions (dynamically generated based on Step 2 choices):

Base questions (always asked):
1. "Siapa target user utama dan situasi paling sering mereka pakai produk ini?"
2. "Outcome utama apa yang harus berhasil dalam 1 sesi penggunaan?"
3. "Fitur mana yang wajib masuk MVP?" (multi-select)
4. "Perkiraan skala pemakaian 3 bulan pertama?" (single-select)
5. "Rencana monetisasi atau model akses?" (single-select)
6. "Metrik sukses apa yang paling penting?"

Conditional questions (shown based on extras selected):
- If auth selected: "Role dan metode login apa yang dibutuhkan?"
- If payment selected: "Payment flow apa yang harus didukung?"
- If AI selected: "Bagian mana yang memakai AI dan bagaimana user mengontrol hasilnya?"

Final question:
- "Ada referensi produk, gaya UI, atau batasan khusus?"

**Max 9 questions.** Paginate if more.

**Design notes:**
- One question at a time (like Typeform / Linear onboarding)
- Progress bar at top
- Smooth transitions between questions
- After last question: "Generate Blueprint" CTA button

---

#### Step 4 — Blueprint Output

**Purpose:** Show all generated artifacts in one organized view.

Layout:
- **Left sidebar:** list of generated artifacts (file tree style)
  - PRD (markdown) ✓
  - Database Schema (prisma) ✓
  - Types (typescript) ✓
  - Architecture (mermaid) ✓
  - API Flow (mermaid)*
  - Design Tokens (json)*
  - (* if applicable)

- **Main panel:** preview of the selected artifact
  - Markdown: rendered document
  - Prisma: syntax-highlighted code
  - TypeScript: syntax-highlighted code
  - Mermaid: rendered diagram
  - JSON: pretty-printed

- **Right panel (collapsible):** metadata
  - Project info summary
  - Tech stack recap
  - Download all (.zip) button
  - Copy / Download individual artifact buttons

- **Bottom bar:** "Edit di Studio" button → opens the full Studio view (for power users)

**Design notes:**
- Sidebar: 240px, dark `#07110f` background
- Main: flexible
- Code blocks: dark `#010403` with green/teal syntax highlighting
- Action buttons: download, copy, view raw

---

### 3. Studio View (Power User / Optional)

Accessible via "Edit di Studio" from Step 4 or direct link.

Layout (4-region):

```
┌─────────────────────────────────────────────────────┐
│                     Top Bar                          │
│  ← Kembali   PRDKit — [project name]   Preview ▶   │
├──────────┬──────────────────────────┬────────────────┤
│          │                          │                │
│  Sidebar │    Main Workspace        │   Right Panel  │
│  (240px) │    (flex)                │   (320px)      │
│          │                          │                │
│  File     │  PRDL code editor OR     │  Properties    │
│  explorer │  visual builder          │  Validation    │
│          │                          │  Warnings      │
│          │                          │                │
├──────────┴──────────────────────────┴────────────────┤
│                 Bottom Dock (output artifacts)        │
│  [PRD] [Schema] [Types] [Diagram] [Tokens]   ...     │
└─────────────────────────────────────────────────────┘
```

**Top Bar:**
- Back button (← Kembali to wizard)
- Project title (editable inline)
- Preview button (opens generated outputs)

**Sidebar:**
- File tree: blueprint.prdl (auto-generated), outputs/
- Collapsible sections
- Add new resource / blueprint buttons

**Main Workspace:**
- Default: PRDL code viewer (syntax highlighted, non-editable for non-tech users)
- Toggle: "Visual" mode → form-based resource editor
- Tab system: Code / Visual / Split

**Right Panel:**
- Context-sensitive properties
- Validation errors/warnings in real-time
- AI assistant chat (minimizable)

**Bottom Dock:**
- Tab bar with artifact types
- Click to preview/download each

---

## Brand & Design System

### Colors
| Token | Value | Usage |
|-------|-------|-------|
| --bg | `#030605` | Page background |
| --panel | `#07110f` | Card/sidebar background |
| --panel-2 | `#0d1b18` | Secondary panel |
| --text | `#effff8` | Primary text |
| --muted | `#8da39c` | Secondary text |
| --line | `rgba(126, 255, 214, 0.14)` | Subtle border |
| --primary | `#00e08f` | Primary accent (green neon) |
| --primary-strong | `#67ffd0` | Hover/active accent |
| --primary-soft | `rgba(0, 224, 143, 0.13)` | Background accent |
| --teal | `#36d8ff` | Secondary accent |
| --rose | `#ff4d7d` | Error/destructive |
| --code | `#010403` | Code block bg |
| --shadow | Specific shadow values | Elevation |

### Typography
- Font family: Inter, system-ui, sans-serif
- Code font: JetBrains Mono or Fira Code
- Scale: 12 / 14 / 16 / 20 / 24 / 32 px

### Spacing
- Base unit: 4px (4/8/12/16/20/24/32/48/64)

---

## Interactions & Animations

### Micro-interactions
- Step transitions: fade + slide (200ms ease)
- Card selection: green border glow (150ms)
- Button hover: subtle scale + brighter green
- Sidebar collapse: smooth width transition (250ms)
- Toast notifications: slide in from top-right

### States
- Loading: spinner with "Memproses..." text
- Empty state (Step 1): subtle gradient + example ideas
- Error state: red border + error message below the field
- Success (Step 4): green checkmark + confetti animation once

---

## AI Integration Points

1. **Idea expansion** (Step 1): User types short idea → button "Kembangkan dengan AI"
2. **Tech suggestions** (Step 2): Default "Biarkan AI pilih" auto-selects based on idea
3. **PRDL generation** (behind the scenes): After Step 3, wizard answers → PRDL compiler
4. **Chat refinement** (Studio view): AI assistant for editing PRDL via chat

---

## Constraint

- Single page application (SPA). No SSR needed.
- All state in memory + localStorage for persistence
- Dark mode only. No light mode.
- Bahasa Indonesia UI (default), English as option.
