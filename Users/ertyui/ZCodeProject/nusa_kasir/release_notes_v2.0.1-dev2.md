## 🔧 v2.0.1-dev.2 — Bug Fixes

### AI Chat Fixes
- 🐛 **Empty bubble then raw JSON then 429** — Fixed 3 root causes:
  1. Tool messages (`role: 'tool'` + assistant tool_calls) now hidden from chat UI via `isInternal` flag
  2. `toJson()` format fixed — assistant tool_calls now properly serialize with `content: null` + `tool_calls: [...]` per OpenAI spec
  3. `dbContext` now sent on round 0 only — prevents redundant tool calls and 429 rate limiting
- Tool results no longer appear as raw JSON chat bubbles

### Toko Online Fixes
- 🐛 **"Gagal menyimpan" + "Cek koneksi internet"** — Fixed edge function auth: removed strict Supabase Auth requirement (app doesn't use Supabase Auth). Uses service_role client directly
- 🐛 Online store tables (`store_settings`, `online_products`) confirmed existing in Supabase DB
- Edge function redeployed with simplified auth

### Dashboard
- 🎨 **Laundry stats pill bar** — Each stat now has transparent colored card wrapper (10px radius, subtle border) instead of plain text
  - Hari Ini: purple, Diproses: blue, Siap: green, Diambil: orange
- Each stat card has color-coded background with matching border

### Build
- APK: v2.0.1 (build 41) — release with `--dart-define=NUSA_DEV=true`
