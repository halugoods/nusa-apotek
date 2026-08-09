# 📋 Audit Report — NUSA Kasir (8 Variants)
**Date:** 2026-08-01  
**Project Type:** Flutter / Android  
**Scope:** Read-only holistic audit of shared code, all eight variant mappings, routes, persistence, cloud sync, settings, RBAC, domain screens, assets, and release/build risk. **No source changes, APK builds, or GitHub releases were performed.**

## Executive Summary

The codebase is not ready for another 8-APK build/release. The previously observed Service HP → Salon contamination path is improved for the *new* product-scoped backup/image paths, but the audit found several release-blocking correctness issues that can still produce wrong data, inaccessible features, or false UI state:

- Branch selection is cosmetic: dashboard/report/finance data is not filtered by selected or employee branch.
- Router has no activation/session/RBAC guard; protected screens can be opened directly by route.
- Cloud restore stages a file but does not replace/reopen the active Drift database until a real process restart; the Settings flow navigates as if restore completed.
- Startup opens/repairs the database before pending restore application.
- Archive extraction accepts untrusted filenames and can write outside the app directory.
- All six domain screens are prototypes with hard-coded zero states and dead create/action controls.
- Theme state is inconsistent and not applied at startup; theme storage is not product-scoped; builder colors disagree with runtime presets.
- Feature initialization enables every feature, overriding product hidden-menu defaults.
- Dashboard/report aggregates include voided transactions and date boundaries disagree.
- Static analysis/tests could not be executed in this environment because the configured Flutter executable was not present at `C:\Users\ertyui\flutter\bin\flutter.bat`; the fallback `flutter` command was also unavailable. This is a verification limitation, not a pass.

**Release decision: BLOCK. Do not build or release until all P0/P1 findings below are fixed and verified on each variant.**

---

## 1️⃣ Code Quality / Verification Summary

| Category | Findings | Risk |
|---|---:|---|
| Data isolation / branch boundaries | 5 | 🔴 Critical |
| Restore / backup safety | 6 | 🔴 Critical |
| Routing / authorization | 4 | 🔴 Critical |
| Domain functionality | 6 screens + dead controls | 🔴 Critical |
| Theme / feature configuration | 5 | 🟠 High |
| Reporting / accounting correctness | 5 | 🟠 High |
| Error handling / lifecycle | 6 | 🟠 High |
| Schema / integrity | 4 | 🟡 Medium |
| Assets / icon delivery | 2 | 🟡 Medium |
| Verification tooling | Flutter analyze/test not run | 🟠 High |

---

## 2️⃣ Architecture & Data Flow

- One Flutter source tree is mutated by `_build_all.py` for eight product variants.
- Local persistence is Drift/SQLite in `nusa_kasir.sqlite`.
- Riverpod holds session, branch, feature-toggle, menu-order, and theme state.
- Supabase Storage stores encrypted backups and images.
- Activation/restore flow:
  `Google account + productId → Supabase path → encrypted backup → pending SQLite/archive → startup extraction`.
- Dashboard flow:
  `session/branch providers → repository queries → summary cards/menu grid`.
  The branch provider is written but not consumed by the important read queries, so it is not a real isolation boundary.
- Router flow:
  `GoRouter routes → screen widgets`; authorization exists mainly in dashboard tap handling, not at route level.

---

## 3️⃣ Variant Inventory

| Variant | Product ID | Android ID | Build default | Product-specific hidden menus |
|---|---|---|---|---|
| Kelontong | `nusa-kelontong` | `com.nusa.kelontong` | Orange | domain screens |
| F&B | `nusa-fnb` | `com.nusa.fnb` | Red | supplier, piutang, spreadsheet + irrelevant domain screens |
| Laundry | `nusa-laundry` | `com.nusa.laundry` | Blue | supplier, piutang, promo, online + irrelevant domain screens |
| Bengkel | `nusa-bengkel` | `com.nusa.bengkel` | Dark gray | online + irrelevant domain screens |
| Salon | `nusa-salon` | `com.nusa.salon` | Stone gray | supplier, branch, piutang, online + irrelevant domain screens |
| Apotek | `nusa-apotek` | `com.nusa.apotek` | Green | promo, piutang + irrelevant domain screens |
| Fotocopy | `nusa-fotocopy` | `com.nusa.fotocopy` | Purple | branch, piutang, online + irrelevant domain screens |
| Service HP | `nusa-servicehp` | `com.nusa.servicehp` | Cyan | promo, branch, online + irrelevant domain screens |

Definitions are internally consistent in `_build_all.py:18-233`, but runtime preset colors do **not** match these build defaults (details in Finding F-04).

---

## 4️⃣ Feature / Route Inventory

Shared router in `lib/app.dart:43-164` registers activation, login, onboarding, setup, home, kasir, checkout, products/categories, stock, transactions, customers, debts, promo, reports, employees, attendance, finance, settings, suppliers, spreadsheet, online orders/store setup, AI, storefront, payment settings, and six domain routes:

- `/meja`
- `/laundry_status`
- `/servis`
- `/booking`
- `/resep`
- `/print_order`

The routes exist syntactically, but route existence is not equivalent to working functionality or authorization.

---

## 5️⃣ Key Findings & Risks

### 🔴 P0 / Release Blocking

#### F-01 — Branch isolation is nonfunctional
**Evidence:**
- Branch picker writes state: `lib/features/dashboard/dashboard_screen.dart:334-426`.
- Dashboard summary calls do not pass branch: `dashboard_screen.dart:174-185,214-227`.
- `ReportRepository.summary()` has no branch argument: `lib/data/repositories/report_repository.dart:31-37`.
- Transaction reads select all rows: `report_repository.dart:8-27`.
- Finance repository supports filtering, but dashboard omits it: `finance_repository.dart:224-246`, called at `dashboard_screen.dart:225-227`.
- `activeBranchProvider` is written but not consistently read: `lib/core/providers.dart:20`.

**Impact:** Selecting Branch A still shows all-branch omzet, counts, finance, online-order, stock, and report information. Employee `branchId` is metadata, not an access boundary. This is a direct data-isolation defect.

**Required before release:** Define all-branch vs branch-scoped semantics; enforce them inside repository SQL queries and every read screen, not only in the branch picker.

#### F-02 — Router authorization bypass
**Evidence:** `lib/app.dart:43-164` defines all routes without `redirect` or route-level auth checks. Dashboard-only checks are at `dashboard_screen.dart:458-503`.

**Impact:** Direct route/deep-link/programmatic navigation can open `/home`, `/keuangan`, `/pengaturan`, `/karyawan`, `/cabang`, and other protected screens without activation/session/RBAC validation.

**Required before release:** Centralize route policy and validate activation, employee session, role, feature availability, and branch scope before every protected route.

#### F-03 — Cloud restore does not become active in the current process
**Evidence:** Settings calls `restoreFromCloud()` at `lib/features/settings/settings_screen.dart:482-485`; repository only writes `.pending` at `activation_repository.dart:153-166`; Settings navigates after staging at `settings_screen.dart:489-498`; pending is applied only in startup at `main.dart:163-165`.

**Impact:** User sees the old open Drift database after “restore”. Subsequent writes may continue against old data. Navigation falsely implies completion.

**Required before release:** Close DB/providers, validate and atomically replace the database, reopen dependencies, or perform a guaranteed full process restart. The UI must not claim success before the new DB is active.

#### F-04 — Six domain screens are nonfunctional prototypes
**Evidence:**
- Salon Booking: hard-coded calendar/empty state, no repository/database, dead month arrows and `Booking Baru`: `lib/features/domain/booking_screen.dart:1-72`.
- Service HP/Bengkel tickets: all counts 0, no persistence, dead `Tiket Baru`: `servis_screen.dart:1-59`.
- Laundry: all six stages show `0 pesanan`; cards are not tappable: `laundry_status_screen.dart:1-53`.
- F&B tables: in-memory grid only; table tap empty: `meja_screen.dart:13-89`.
- Apotek prescriptions: all stats 0, dead `Resep Baru`: `resep_screen.dart:5-59`.
- Fotocopy orders: all six chips and `Order Baru` are dead: `print_order_screen.dart:5-54`.

**Impact:** The domain-specific functionality advertised by the eight products cannot be used or persist data. Salon Booking and Service HP are guaranteed broken in real use.

**Required before release:** Implement each domain’s data model, Drift migration, repository, create/edit/status flows, validation, loading/error/empty states, and route/RBAC policy—or remove/hide the incomplete screens and controls until implemented.

#### F-05 — Backup/archive extraction can write outside app storage
**Evidence:** Archive entries are joined directly to app dir at `lib/main.dart:90-94` and `activation_repository.dart:206-212`; `BackupCrypto.unpackFiles()` accepts arbitrary names at `backup_crypto.dart:80-109`.

**Impact:** A corrupted or compromised cloud archive containing `../...` or absolute paths can overwrite files outside the intended directory.

**Required before release:** Reject absolute paths, separators/traversal, dot segments, unexpected filenames, oversized entries, malformed lengths, and archives without a validated manifest. Extract into a temporary directory and atomically commit only after validation.

#### F-06 — Pending restore failure discards the restore marker
**Evidence:** `main.dart:102-105` catches all extraction/write errors and clears pending state.

**Impact:** A failed restore can leave old data active and destroy the only retry signal.

**Required before release:** Preserve staged backup, record failure, retry safely, and rollback atomically.

### 🟠 P1 / Must Fix Before Build

#### F-07 — Startup order opens DB before pending restore
`main.dart:149-150` calls `_repairPinLength()`, which opens DB at `main.dart:25-49`, before pending restore at `main.dart:163-165`. This contradicts the intended restore-before-open flow and risks locks/repairing data that is immediately replaced.

#### F-08 — Feature defaults override product hidden menus
`settings_screen.dart:127-130` fills every `_allFeatures` entry as `true`; dashboard gives explicit toggles precedence at `dashboard_screen.dart:936-943`. Irrelevant domain menus can appear in every variant.

#### F-09 — Saved theme is not loaded/applied at startup
Startup only loads theme mode at `main.dart:173-177`; it never loads `SecureStore.getThemePreset()` or calls `NusaConfig.applyTheme()`. Theme is first applied when Settings opens (`settings_screen.dart:109-114`). Initial visual state is therefore wrong/stale.

#### F-10 — Theme provider/default/storage are inconsistent
- Provider default is hard-coded `'bengkel'`: `lib/core/providers.dart:51-54`.
- Settings default is `NusaConfig.productId` (`nusa-kelontong`, not valid key `kelontong`): `settings_screen.dart:56-58`.
- Storage key `nusa_theme_preset` is global: `secure_storage.dart:107-113`, so variants can overwrite each other’s preference.
- Picker updates local state and `NusaConfig.applyTheme()` but does not reliably update `themePresetProvider` (review `settings_screen.dart:644-657` against `app.dart:205-214`).

#### F-11 — Builder colors and runtime presets disagree
`_build_all.py:21-23,47-50,74-77,128-131,155-158,182-185,209-212` differs from `nusa_config.dart:41-80` for F&B, Laundry, Salon, Apotek, Fotocopy, and Service HP. A user selection can silently replace the product’s expected palette; the initial/default and picker palette are not one source of truth.

#### F-12 — Icon requirement is not implemented
`pubspec.yaml:68-77` declares eight themed icon directories, but each contains only `README.md`; `dashboard_screen.dart:1368-1406` still maps to shared SVGs. No `assets/icons/{variant}/{theme}/{feature}.png` loader exists. The requested PNG icon system is absent.

#### F-13 — Cloud image migration flag is global
`secure_storage.dart:148-152` stores `nusa_images_migrated`; startup checks it at `main.dart:119-123`. It is not scoped by account or product, so switching account/variant can skip required migration into the new namespace.

#### F-14 — Dashboard/report totals include voided transactions
`report_repository.dart:31-37` summary, `148-160` daily revenue, and `188-199` payment totals process all transactions. `status == Normal` is applied only in profit/loss (`45-49`). Dashboard/report totals can disagree after a void.

#### F-15 — Date boundaries are inconsistent
`report_repository.dart:11-23` expands date bounds by a day; `transaction_repository.dart:89-95` uses strict `>` at midnight; transactions screen has separate client-side bounds at `transactions_screen.dart:44-75`. Different screens can show different totals for the same date.

#### F-16 — Reports load entire tables into memory
`report_repository.dart:297-314` fetches complete expense/payroll/waste/liquidity tables and filters dynamically in Dart. This will degrade on real data and can fail on unexpected dynamic `.date` types.

#### F-17 — Settings cloud restore has an async lifecycle bug
`settings_screen.dart:481-487` performs `setState` after an await without an immediate mounted guard. If the sheet/screen closes during network activity, it can throw `setState() called after dispose`.

#### F-18 — Dashboard failures are silently converted to fake zeros
Initialization/data loading catches broad exceptions across `dashboard_screen.dart:103-255,258-331`, leaving default `Rp 0`, zero counts, and empty lists with no error/retry state.

#### F-19 — Global error handler hides recovery
`main.dart:56-68` logs errors and returns `true` for every platform error. Production users can remain on stale/partially initialized UI with no recovery path.

#### F-20 — PIN repair is destructive and conflicts with settings
`main.dart:31-49` forces six digits and pads/truncates every employee PIN. It overrides a configured four-digit mode and irreversibly changes credentials before the user can interact with Settings.

#### F-21 — Owner-only policy is inconsistent
Config calls screens owner-only (`nusa_config.dart:250-254`), but dashboard allows Owner **or Manager** (`dashboard_screen.dart:469-471`) and dialog says Owner/Manager (`523-525`). Decide and enforce one policy centrally.

#### F-22 — Direct activation state is not centralized
`app.dart:43-164` lacks activation/session redirects. `activation_repository.dart:39-60` saves local activation before cloud registration; on network failure local activation may remain active. Decide whether this offline behavior is intended, then enforce revocation/device limits consistently.

### 🟡 P2 / Integrity and Maintainability

#### F-23 — Schema lacks uniqueness for business identifiers
Product SKU/barcode, transaction invoice, and promo code are not unique: `tables.dart:7-24,33-49,60-71`. Duplicate lookup and invoice collisions are possible.

#### F-24 — Settings singleton has a check-then-insert race
`settings_repository.dart:13-16` can race on first use. Use an atomic insert/upsert/transaction.

#### F-25 — Product stock is global while transactions are branch-aware
Products have no branch ID (`tables.dart:7-24`), while transactions do (`33-49`). Decide whether stock is global or add branch-scoped inventory before claiming branch isolation.

#### F-26 — Session behavior is confusing for non-remembered logins
`employee_session.dart:20-23` treats `remember=false` as immediately expired; fingerprint activation creates such sessions (`activation_screen.dart:804-810`). In-memory use works, but any restore/validation path treats it as expired. Calls to `touch()` are also fire-and-forget (`dashboard_screen.dart:573-575,625-626`).

#### F-27 — Legacy/current backup key formats share a path
Legacy methods use activation-key encryption (`activation_repository.dart:228-266`) while current methods use Google ID (`107-147`) under the same product path. Migration/version metadata is absent; old payloads may be unreadable by the new flow.

#### F-28 — Backup archive has no manifest/account/product/schema validation
`activation_repository.dart:119-133` packs basenames only. There is no product/account/schema/checksum metadata before restore.

#### F-29 — Domain menus are both hidden and unauthorized
All six IDs are in `hiddenMenus` (`nusa_config.dart:257-263`), and no role contains them in `roleAccess` (`240-246`). Even if enabled in Settings, `_handleMenuTap` blocks them (`dashboard_screen.dart:475-479`). Direct routes remain exposed because the router is unguarded.

#### F-30 — Stock decrement is race-prone and permits false successful sales
`product_repository.dart:67-73` performs read-modify-write and clamps negative stock to zero. Concurrent checkout/online-order operations can lose updates; an insufficient-stock sale can still succeed while inventory silently becomes zero. Callers include `checkout_screen.dart:236-253`, `online_orders_screen.dart:228`, and `stock_screen.dart:113-162`.

#### F-31 — Sales and voids do not reconcile stock movements and loyalty side effects
`transaction_repository.dart:10-36` inserts a sale without a corresponding `StockMovements` record. Void handling at `99-134` restores stock but does not add compensating movements, reverse customer spend/points, or reverse promo usage. Reports and inventory history can never fully reconcile.

#### F-32 — Stock opname finalization is not idempotent
`stock_count_repository.dart:75-117` has no completed-state/duplicate-finalization guard. Calling finalize twice reapplies differences and inserts duplicate movements.

#### F-33 — Debt payments are not atomic or validated
`debt_repository.dart:47-76` inserts payment and updates debt in separate operations; zero/negative payments and overpayment are accepted, and failures can leave orphan payments or inconsistent remaining balances.

#### F-34 — Public Supabase online-order RLS exposes all orders
`supabase/migrations/0004_online_store.sql:43-47` uses public `SELECT USING (TRUE)` and unrestricted public insert checks. Customer names, phones, items, notes, and payment data may be readable by anyone, while spoofed orders can be inserted.

#### F-35 — Offline sync queue is declared but unused; background order sync can duplicate records
`tables.dart:211-218` defines `SyncQueue`, but no usage was found. `stok_alert_worker.dart:129-159` deduplicates only orders still marked `Online Baru`, so already-processed remote orders can be reinserted; errors are swallowed at `181`.

#### F-36 — Cashier/attendance/loyalty operations have concurrency and lifecycle gaps
Attendance uses strict `>` at midnight and has no employee/day uniqueness (`attendance_repository.dart:125-135,191-223`). Cashier sessions can have multiple active rows (`cashier_session_repository.dart:7-27,39-48`). Customer `addSpent`/`redeemPoints` are read-modify-write (`customer_repository.dart:19-37`), and voids do not reverse loyalty effects.

#### F-37 — Image local cache can collide across categories/records
`image_storage_service.dart:52-65,86-115` caches by basename at the app root. Identical filenames from product/employee/settings categories can overwrite each other and display the wrong image; storage listing is not checked for directories.

#### F-38 — CRUD integrity is incomplete
Category rename does not update denormalized product category (`category_repository.dart:29-33`); role rename does not update employees despite its comment (`role_repository.dart:75-85`); product/supplier/category/branch deletes lack dependency checks (`product_repository.dart:86-88`, `supplier_repository.dart:48-49`, `category_repository.dart:24-27`, `branch_repository.dart:32-34`).

#### F-39 — Async lifecycle hazards remain in settings/dashboard/login/splash
Examples: `settings_screen.dart:153-167,559-563,1762-1765` set state after awaits without complete mounted protection; cloud sync uses dead context at `315-333`; `_bukaKasir` sets state after await at `dashboard_screen.dart:683-689`; login fires `_doLogin` without await at `login_screen.dart:55-68`; splash can navigate after reverse completion at `splash_screen.dart:67-71`.

#### F-40 — Build orchestration can publish wrong or stale APKs
Python builder restores mutated files only on normal completion (`_build_all.py:416-474`), does not clear `nusa_builds` (`15,480-487`), and does not verify generated identities (`320-381`). The shell builder has broken `$10/$11/$12` arguments and malformed map replacement (`_build_all.sh:50-80`), masks Flutter failures via `tail` (`99-108`), does not restore Firebase config (`18-32,61-63`), and the legacy batch builder does not swap Firebase or reliably restore on failure (`_build_all.bat:14-95`). `do_build.bat:3-9` writes success unconditionally and may copy stale APKs.

#### F-41 — License-manager has a hardcoded admin credential
`supabase/functions/license-manager/index.ts:38,117-122` accepts static admin key `280303`, and CORS exposes `x-admin-key` (`:34`). Anyone obtaining the key can invoke service-role license generation/list/revoke/delete operations. This credential must be rotated and removed from source immediately.

#### F-42 — Online-store Edge Function is unauthenticated and cross-tenant
`supabase/functions/online-store/index.ts:11-28,35-99` uses the service-role key without authenticating the caller or validating `store_id`. A caller can read, overwrite, delete, or rewrite another store's products/orders by supplying its ID.

#### F-43 — Supabase online-order RLS is public read/write
`supabase/migrations/0004_online_store.sql:43-48` permits public `INSERT ... WITH CHECK (TRUE)` and `SELECT ... USING (TRUE)`. This exposes customer PII/order contents and permits spoofed cross-tenant orders.

#### F-44 — Backup Storage bucket is anonymously listable and mutable
`supabase/migrations/0002_storage_backups.sql:27-45` grants anonymous/authenticated insert/select/update/delete based only on bucket ID. Any client may enumerate, download, overwrite, or delete backups for other users/products. Product-scoped paths do not compensate for missing authorization.

#### F-45 — Activation registration trusts caller-supplied Google identity
`supabase/functions/register_activation/index.ts:51-66,68-186` requires only a JSON `googleUserId`; it does not verify a Google-issued JWT. License status/key/serial and binding operations can be queried or raced using a supplied identity. The binding check/update is also non-transactional.

#### F-46 — Employee PINs are plaintext
`tables.dart:73-79` stores PIN text and `login_screen.dart:88-96` compares it directly. A local DB or backup compromise exposes all employee credentials. The destructive padding/truncation at `main.dart:36-48` compounds the issue.

#### F-47 — AI assistant endpoint is unauthenticated and abuseable
`supabase/functions/ai-assistant/index.ts:32-49,67-113` accepts arbitrary prompts/context, spends the server API key without auth/rate limits/length validation, and returns internal exception text. Add authentication, tenant checks, quotas, input limits, and sanitized errors.

#### F-48 — Public image bucket exposes sensitive images
`supabase/migrations/0006_images_public.sql:3-16` makes `nusa-images` publicly readable. Employee photos, QRIS images, and store logos may be exposed despite the intended product-image use.

#### F-49 — Inactive employees can still authenticate
`features/auth/login_screen.dart:54-64,89-112` accepts employees without checking nullable `status`; terminated/suspended staff can retain PIN/NFC access until deletion.

#### F-50 — Login NFC path can leave the spinner stuck
`features/auth/login_screen.dart:55-68` invokes `_doLogin(emp)` without awaiting it. Store-name lookup or navigation errors can leave `_loading` true and produce an unhandled async error.

#### F-51 — Report failures appear as valid empty/zero data
`features/reports/reports_screen.dart:357-371,403-409,481-486,660-667` ignores `FutureBuilder` errors and renders blank/zero content. Users cannot tell a failed query from no records.

#### F-52 — Online-store Edge Function and WebView flows lack robust failure controls
`features/online_orders/online_store_setup_screen.dart:151-155,178-254,664-671` overlaps `_saving` ownership, initializes WebView during `build()`, and has no timeout/load-error/progress recovery. Service-role endpoint risks are covered by F-42.

#### F-53 — Mixed navigation stacks and expired-session route are inconsistent
`main.dart:179-192` sends activated-but-expired users to `/activation` instead of a normal login route. `app.dart:42-164` uses GoRouter while `activation_screen.dart:281-287` pushes imperative `MaterialPageRoute`, creating back-stack/deep-link inconsistencies.

#### F-54 — Domain schema/repository layer is absent
`data/database/tables.dart:1-296` has no booking, laundry order, table/room, print order, prescription, or service-ticket tables; `data/repositories` has no corresponding repositories. This confirms the six domain screens cannot be made persistent by UI-only fixes.

#### F-55 — Activation async flows can call setState after disposal
`core/activation/activation_screen.dart:84-103,206-235,253-267` performs Google sign-in, license, and key operations across awaits without complete mounted protection. Navigating away during a request can throw and leave activation state inconsistent.

#### F-56 — Checkout has a duplicate-submit race
`features/checkout/checkout_screen.dart:194-223` validates asynchronously before setting `_loading`. Two rapid taps can both pass validation and write duplicate transactions/stock changes. The in-flight guard must be set synchronously at entry.

#### F-57 — Product search has stale-result race
`features/products/products_screen.dart:54-57,77-95` starts `_load()` for every keystroke without cancellation/request sequencing; an older slow query can overwrite newer results.

#### F-58 — POS async employee load has lifecycle gap
`features/pos/pos_screen.dart:88-95` can call `setState` after the widget is disposed during the employee query.

#### F-59 — Enabled domain menus always fail RBAC
`nusa_config.dart:240-246` omits all six domain IDs from every role, while dashboard advertises them at `dashboard_screen.dart:90-95` and routes exist at `app.dart:152-163`. If enabled, tapping them always shows Access Restricted rather than navigating.

#### F-60 — Release signing is not production-ready
`android/app/build.gradle.kts:31-34` uses debug signing for release builds. APKs are not Play Store/release signing-ready.

#### F-61 — Firebase fallback artifact has the wrong package identity
`android/app/google-services-orig.json` targets `com.nusa.kasir`, while the current baseline is Kelontong (`nusa_config.dart:5,9,12`, `build.gradle.kts:8,19`, manifest `:20`). A fallback restore could reintroduce an incompatible Firebase configuration.

#### F-62 — All variants expose all eight product palettes
`nusa_config.dart:38-93` lets each variant select every product theme. This conflicts with the “one palette per variant” differentiation and can make a product appear branded as another product.

#### F-63 — Domain routes have zero automated coverage
The existing `test/` suite covers activation keys, customer/product repositories, formatting, and a basic widget test, but no Booking, Laundry, Meja, PrintOrder, Resep, or Servis tests. This leaves the six known domain stubs completely unprotected from regression.

#### F-64 — License/activation tables lack explicit RLS
`supabase/migrations/0001_init.sql:3-19,29` creates license/activation tables but does not explicitly enable RLS or define restrictive policies. The intended “Edge Functions only” access model is not enforced at the database layer.

#### F-65 — Database provider lifecycle is unmanaged
`core/providers.dart:15` constructs `AppDatabase()` without a disposal hook, while `main.dart:198` closes a different database instance. This can leak SQLite resources and create inconsistent ownership during tests/restarts.

#### F-66 — Startup suppresses initialization failures
`main.dart:151-178,198-204` swallows failures for DB repair, Workmanager, notifications, Supabase, restore, and workers, then always launches the app. Broken backup/auth/sync can therefore appear as a normal healthy app without recovery UI.

#### F-67 — Supabase anon configuration is embedded in source defaults
`core/config/nusa_config.dart:14-15` ships the project URL and anon JWT fallback. The anon key is not a secret by itself, but this makes environment separation/rotation dependent on source and requires verified RLS everywhere.

#### F-68 — Dependency override needs compatibility verification
`pubspec.yaml:58-62` pins `rxdart: 0.27.5` to reconcile incompatible transitive constraints. Every dependency upgrade must rerun the complete test/build matrix because the override can hide package compatibility defects.

---

## 6️⃣ Test Results / Verification

| Check | Status | Notes |
|---|---|---|
| Flutter static analysis | ⚠️ Not run | Configured `C:\Users\ertyui\flutter\bin\flutter.bat` was absent; system `flutter` was unavailable. No pass/fail claim is made. |
| Flutter test suite | ⚠️ Not run | Same missing SDK executable limitation. |
| Existing test inventory | ⚠️ Incomplete | `test/activation/activation_key_test.dart`, repository tests, formatting test, and widget test exist, but execution was unavailable. |
| APK build | ⛔ Intentionally skipped | User requested audit/report before fixes/build/release. |
| GitHub release | ⛔ Intentionally skipped | No outward-facing release action performed. |

---

## 7️⃣ Required Fix Order Before Any APK Build

1. **Data boundary:** branch policy, repository SQL filters, product/account namespace, inventory semantics.
2. **Restore safety:** real restart/reopen, startup ordering, atomic replacement, archive manifest/path validation, failure retry.
3. **Authorization:** centralized GoRouter activation/session/RBAC/feature guards.
4. **Domain decision:** implement all six screens end-to-end or remove/hide incomplete UI and routes for the release.
5. **Theme/config:** one canonical variant palette source, product-scoped saved theme, startup application, provider synchronization.
6. **Feature visibility:** initialize toggles from variant defaults; prevent irrelevant menus from appearing.
7. **Accounting:** void filtering and one date-range contract across repositories/screens.
8. **Error states:** visible loading/error/retry in dashboard/settings/sync flows; remove misleading silent fallback zeros.
9. **Schema integrity:** uniqueness constraints/migrations and atomic Settings singleton initialization.
10. **Assets:** implement and verify actual PNG icon matrix before declaring icon work complete.
11. **Verification:** run `flutter analyze`, all tests, targeted tests for each P0/P1, then manual device tests on all 8 variants.
12. **Only after clean verification:** build APKs sequentially, inspect each artifact/package ID, then release.

---

## 8️⃣ Manual Test Checklist (Flutter)

### Data isolation matrix
- [ ] Install Service HP and create unique owner/employee/product/transaction/image data.
- [ ] Install Salon with same Google account and a different license; verify employees, owner slug/name, products, statistics, images, backups, and settings are empty/independent.
- [ ] Repeat pairwise for all 8 variants using the same Google account.
- [ ] Upload and restore each product backup; verify only matching product namespace restores.
- [ ] Switch Google accounts on one product; verify image migration and backups do not reuse the previous account.

### Activation and restore
- [ ] Fresh install with no local employees and matching product backup: restore, force-close/reopen, verify restored DB is active.
- [ ] Restore while app is open: verify active database changes only after a guaranteed restart/reopen; no old data writes are possible during transition.
- [ ] Corrupt/truncate backup: verify failure is visible and backup remains retryable.
- [ ] Archive entries containing traversal/absolute paths: verify rejected and no outside file is written.

### Routing and RBAC
- [ ] Open every protected route directly before activation, after activation without login, and as each role.
- [ ] Verify Owner-only policy for Owner, Manager, Kasir, Gudang, Finance exactly matches product decision.
- [ ] Verify hidden product menus cannot be reached through direct route or programmatic navigation.

### All eight product flows
- [ ] Quick Setup → Home → employee stats/card.
- [ ] Settings → Security: PIN pad appears; correct/incorrect PIN behavior; fingerprint/NFC fallback.
- [ ] Kelola Fitur: every item drag-reorders; order persists after restart; irrelevant domain items remain hidden.
- [ ] Theme palette: select each allowed preset, restart, verify colors and labels; no cross-variant preference leakage.
- [ ] Open Kasir, create/close session, checkout, receipt, stock deduction, promo, debt, payment methods.
- [ ] Products, categories, stock, stock opname, customers, employees, attendance, finance, reports, suppliers, branches, online orders, spreadsheet, AI, printer, backup.
- [ ] Verify every async failure shows an actionable error/retry state.

### Domain screens (only if included in release)
- [ ] Salon: create/edit/cancel booking, month navigation, stylist/customer/time conflict.
- [ ] Service HP/Bengkel: create ticket, status transitions, costs/spareparts, customer handoff.
- [ ] Laundry: create order, stage transitions, ready/delivered counts.
- [ ] F&B: table state, table order, occupancy persistence.
- [ ] Apotek: prescription creation, patient/doctor/dosage/batch validation.
- [ ] Fotocopy: service selection, quantity/pages/paper/binding, order persistence.

### Reporting correctness
- [ ] Void transaction disappears from omzet/count/payment totals everywhere.
- [ ] Midnight and date-boundary transactions appear exactly once in all screens.
- [ ] Branch A/B totals differ correctly and unassigned/all-branch behavior is explicit.

---

## Final Verdict

**Not safe to build/release yet.** The audit found concrete release-blocking bugs beyond the three currently visible symptoms. Fixing only the three symptoms would leave branch data exposure, route authorization bypass, inactive cloud restores, nonfunctional domain features, unsafe archive extraction, wrong startup themes, and incorrect financial totals. A next build should happen only after the P0/P1 checklist is implemented and verified with the matrix above.
