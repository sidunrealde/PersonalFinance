# Project Research Summary

**Project:** Household Financial & Life Organizer
**Domain:** Offline-first cross-platform household finance + life management (India, 2-person)
**Researched:** 2026-03-17
**Confidence:** HIGH

## Executive Summary

This is a two-person household finance app with a unique "Privacy Wall" — shared expenses are visible to both partners, while private wallets are mathematically isolated at every layer. The expert approach is **offline-first with local SQLite as the source of truth**, syncing to a cloud PostgreSQL backend via polling. Flutter (Dart) is the clear winner for single-codebase Android + Web, Drift provides best-in-class typed SQLite ORM with reactive streams, and Supabase delivers PostgreSQL with Row Level Security, auth, storage, and auto-generated REST APIs — all on a free tier. There is no need for a separate backend server; Supabase's PostgREST replaces it entirely.

The recommended architecture treats the local Drift database as the authority for all reads and writes. The UI never talks to the cloud directly — every interaction flows through Repository → DAO → local SQLite. A sync engine (outbox pattern) drains a queue of local changes to Supabase when online, and pulls remote changes via timestamp-based delta queries. RLS policies on Supabase enforce the Privacy Wall server-side, while the Repository layer enforces it client-side (defense-in-depth). This architecture is well-proven in offline-first mobile apps and maps cleanly to the project's constraints.

The primary risks are: (1) **sync correctness** — sync loops from conflated timestamps, FK ordering violations, and clock skew can silently corrupt data or drain free-tier quotas; (2) **floating-point money** — using `double` for INR amounts will accumulate visible rounding errors; (3) **RLS policy gaps** — any new table without RLS breaks the entire Privacy Wall; and (4) **Indian bank SMS diversity** — regex parsers for 10+ bank formats require ongoing maintenance. All four are well-understood problems with documented mitigation strategies that must be designed in from Phase 1, not retrofitted.

## Key Findings

### Recommended Stack

Flutter + Dart eliminates the cross-platform risk: single codebase compiles to native Android (ARM) and Web (JS/WASM). Drift (SQLite ORM) provides type-safe queries, reactive `watch()` streams, isolate support, and schema migrations — making it the best offline-first foundation for relational financial data. Supabase replaces an entire backend stack (PostgreSQL + PostgREST + Auth + Storage + Edge Functions) within a free tier of 500MB DB, 50K MAU, 1GB storage, and 5GB bandwidth. Riverpod handles state with compile-time safety and no `BuildContext` dependency — critical for accessing state in sync services.

**Core technologies:**
- **Flutter 3.41+ / Dart 3.7+**: Cross-platform UI — single codebase for Android + Web, Impeller rendering, null safety
- **Drift 2.32+**: Local SQLite ORM — type-safe queries, reactive streams, migration framework, isolate support
- **Supabase (PostgreSQL)**: Cloud backend — PostgREST auto-API, RLS for Privacy Wall, Auth (JWT), Storage, Edge Functions
- **Riverpod 2.6+**: State management — compile-time safe, testable without widget tree, `AsyncValue` for loading states
- **go_router 14+**: Declarative routing — deep links, auth redirect guards, web URL support
- **mfapi.in**: Free mutual fund NAV API — 10K+ Indian schemes, no auth, updated 6x daily
- **Freezed + json_serializable**: Immutable data models — `copyWith`, `==`, auto JSON serialization

**Key stack decision — no separate backend:** PostgREST auto-generates CRUD APIs from the PostgreSQL schema. RLS enforces authorization at the DB level. Edge Functions handle custom logic. For 2 users, adding a backend server doubles the deployment surface for zero benefit.

**Free-tier risk:** Supabase pauses free projects after 1 week of inactivity. Mitigated by a GitHub Actions cron that pings the project every 5 days (10 lines of YAML, zero cost). If Supabase changes this policy, Neon PostgreSQL is the strongest fallback (auto-wake in 350ms, no pausing) but would require building API and storage layers.

### Expected Features

**Must have (v1.0 — the reason users choose this app):**
- Privacy Wall (shared + private wallets with strict isolation) — *core value proposition, no competitor has this*
- Offline-first transaction management (CRUD, categories, recurring) — *non-negotiable constraint*
- Budget tracking with alerts at 80%/100% thresholds — *primary daily use case*
- SMS auto-capture of bank/UPI transactions (Android) — *prevents manual entry fatigue, the #1 cause of finance app abandonment*
- Shopping lists with per-list wallet linking and auto-deduct on purchase — *daily household workflow, unique integration*
- Basic analytics (category charts, monthly summary, budget vs actual) — *necessary feedback loop*
- Cross-platform sync via polling with last-write-wins — *both users need real-time(ish) visibility*

**Should have (v1.1 — wealth management + documents):**
- Investment tracking (MF + stocks) with auto NAV/price fetch, XIRR
- Financial goals (shared + private)
- Document vault (receipts + standalone docs following wallet privacy rules)
- Wallet transfers (all directions) and split transactions

**Defer (v2.0+ — life organizer + deep analytics):**
- Full life organizer (tasks, recurring chores, household inventory, maintenance schedules)
- Unified calendar view (financial events + life events + tasks)
- Subscription tracker, seasonal planning, emergency contacts
- Deep analytics (spending trends, merchant analysis, net worth, year-end summary)
- Tax implications (LTCG/STCG flagging), rebalancing alerts

### Architecture Approach

Local-first architecture where the Drift SQLite database is the single source of truth. All UI reads come from local DB via reactive Drift streams → Riverpod providers. All writes go to local DB first (instant, works offline), then enqueue to a sync queue (outbox pattern). A sync orchestrator drains the queue when online (push), and pulls cloud changes via timestamp-based delta queries (pull). Privacy is enforced at four independent layers: UI filtering, Repository wallet-scoping, local DB query scoping, and Supabase RLS policies.

**Major components:**
1. **UI Layer** — Flutter screens + widgets, `go_router` with auth guards, `ref.watch` for reactive data
2. **State Layer (Riverpod)** — Providers per domain (auth, wallet, transaction, sync, investment, shopping), exposing `AsyncValue<T>` streams
3. **Repository Layer** — Privacy enforcement boundary; every method validates `walletId ∈ visibleWalletIds` before any data access
4. **Data Layer (Drift DAOs)** — Type-safe SQLite queries with `watch()` streams; one DAO per domain (transactions, wallets, categories, investments, shopping, documents, goals, sync queue)
5. **Sync Engine** — SyncOrchestrator (timer + connectivity), SyncQueueProcessor (push), RemotePuller (pull), ConflictResolver (LWW via `server_updated_at`)
6. **Platform Services** — SMS parser (Android-only, conditional import), NAV/stock fetcher (client-side), notification service, file manager

**Project structure:** Feature-based (`lib/features/`) for UI, layered (`lib/data/`, `lib/services/`, `lib/providers/`) for infrastructure. Supabase migrations in `supabase/migrations/`.

### Critical Pitfalls

1. **Sync Loop (Critical, Phase 4)** — If a single `updated_at` column is used for both local writes and sync pulls, upserts from pull create new sync queue entries → infinite push/pull loop that burns free-tier bandwidth in hours. **Prevent:** Separate `updated_at` (local writes only) from `synced_at` (remote pulls only); use `is_synced` boolean flag; dedicated `upsertFromRemote()` DAO method that never touches `updated_at`.

2. **Floating-Point Money (Critical, Phase 1)** — Dart `double` gives `0.1 + 0.2 = 0.30000000000000004`. After thousands of transactions, budgets visibly drift by paisa amounts. **Prevent:** Store ALL amounts as integers in paise (`₹500.00` → `50000`). Use `IntColumn` in Drift, `bigint` in Supabase. Display conversion at UI layer only. Create a `Money` value object.

3. **RLS Policy Gaps (Critical, Phase 1)** — Every new table without RLS policies is a complete Privacy Wall breach. Views bypass RLS by default. **Prevent:** Auto-enable RLS event trigger on every new table; CI gate with pgTAP tests asserting RLS on all public tables; `security_invoker = true` on all views; revoke `anon` role access globally.

4. **Sync Queue FK Ordering (Critical, Phase 4)** — If a category INSERT fails but a child transaction INSERT proceeds, Supabase rejects with FK violation → queue stuck permanently. **Prevent:** Dependency-aware batch ordering (parents before children); transactional batches via Supabase RPC; on FK error, requeue to end.

5. **Clock Skew in LWW (Critical, Phase 4)** — Phone clocks can be minutes off; wrong `updated_at` makes the "wrong" edit win silently. **Prevent:** Use `server_updated_at` (set by DB trigger) for all conflict resolution; pull queries filter by server timestamp, not client timestamp.

6. **Drift Web Storage Limitations (Moderate, Phase 1)** — Firefox private browsing uses in-memory DB (data lost on tab close); Chrome Android has no shared workers (multi-tab corruption); missing COOP/COEP headers degrades storage backend. **Prevent:** Check `chosenImplementation` at startup and warn users; serve COOP/COEP headers on Vercel; treat web DB as cache, not source of truth.

7. **Transfer Atomicity (Critical, Phase 2)** — Wallet transfers create two linked transactions; if one syncs and the other fails, money appears to vanish. **Prevent:** `transfer_ref` UUID links paired legs; sync queue groups same `transfer_ref` entries; Supabase RPC for atomic paired INSERT.

## Implications for Roadmap

Based on combined research, the architecture dependency graph, feature priorities, and pitfall timing constraints, I recommend **10 phases** organized by dependency order and risk frontloading.

### Phase 1: Foundation & Schema
**Rationale:** Everything depends on the database schema, auth, RLS infrastructure, and wallet structure. Getting integer money, RLS auto-enforcement, and the Privacy Wall's DB backbone correct here prevents costly rework in every subsequent phase.
**Delivers:** Supabase project with PostgreSQL schema + RLS policies + helper functions; Flutter project scaffold with Drift database, all table definitions, integer-paise money convention; Supabase Auth integration; household + wallet creation flow; COOP/COEP headers on Vercel.
**Addresses features:** Authentication, household setup, wallet system (shared + private), data encryption in transit.
**Avoids pitfalls:** #2 (float money — integer paise from day 1), #3 (RLS gaps — auto-enable trigger + pgTAP CI), #12 (`auth.uid()` NULL — explicit checks + `TO authenticated`), #6 (web storage — header config).

### Phase 2: Core Data Layer & Privacy Wall
**Rationale:** The Repository layer with privacy scoping, Drift DAOs, Riverpod providers, and the sync queue table form the backbone that every feature builds on. The Privacy Wall's client-side enforcement must be validated before any feature code touches wallet data.
**Delivers:** Drift DAOs for wallets, transactions, categories; Repository layer with `_assertWalletAccess()` on every operation; Riverpod providers wired to repositories; sync queue table and basic enqueue-on-write; `Money` value object; `formatCurrency()` utility.
**Addresses features:** Transaction management (CRUD), category management, per-wallet categories, multi-wallet support, wallet transfers, split transactions.
**Avoids pitfalls:** #11 (stored balance — derived `SUM()` queries), #7 (transfer atomicity — `transfer_ref` design), #16 (Indian number formatting — central utility).

### Phase 3: Core UI & Ledger
**Rationale:** With the data layer solid, UI development is fast — just wire screens to Riverpod providers. Building the ledger, dashboard, and transaction forms validates the full stack (UI → Provider → Repository → DAO → SQLite) before adding sync complexity.
**Delivers:** Dashboard with shared vs personal toggle; transaction CRUD screens + quick-add; category management per wallet; transaction list with search, filter, sort; basic wallet balance display (derived).
**Addresses features:** Dual view (unified + separate dashboards), transaction search & filter, INR currency with Indian number formatting, session management.
**Avoids pitfalls:** #16 (formatting — use central utility).

### Phase 4: Sync Engine
**Rationale:** Sync is the highest-risk component. Building it after the core data layer (but before feature-heavy phases) means you can validate sync correctness with existing transaction data before the schema grows complex.
**Delivers:** Full push + pull sync cycles; sync queue processor with dependency-aware ordering; remote puller with `server_updated_at` delta queries; LWW conflict resolution; connectivity monitoring; sync status UI; exponential backoff; sync-in-isolate for non-blocking UI.
**Addresses features:** Offline-first with sync, near real-time polling, last-write-wins, cross-platform sync, local + cloud backup.
**Avoids pitfalls:** #1 (sync loop — separate timestamps), #4 (FK ordering — dependency-aware batches), #5 (clock skew — server timestamps), #14 (backlog starvation — batch limits + dedup + priority ordering), #10 (Supabase pausing — keep-alive cron setup).

### Phase 5: Budgets & Recurring Transactions
**Rationale:** Budgets and recurring transactions are the primary daily use case after basic transaction logging. They depend on the transaction infrastructure (Phase 2) and sync (Phase 4) being solid, and they're a prerequisite for shopping list auto-deduct (which compares against budget).
**Delivers:** Category budget definitions with monthly rollover option; budget progress bars and alerts at 80%/100%; recurring transaction engine (daily/weekly/monthly/yearly); push notifications for budget thresholds and recurring reminders.
**Addresses features:** Budget tracking per category, budget alerts, recurring transactions, bill reminders, basic notifications.
**Avoids pitfalls:** None specific — standard CRUD patterns.

### Phase 6: Shopping Lists
**Rationale:** Shopping lists are a daily household tool and a unique differentiator (auto-deduct on purchase). They depend on the transaction + budget infrastructure. Building them as a standalone phase keeps the scope focused.
**Delivers:** Shopping list CRUD with wallet linking; list item management with estimated costs; purchase check-off → auto-create expense transaction in linked wallet; estimated vs actual cost comparison; list-level budget impact preview.
**Addresses features:** Multiple named shopping lists, per-list wallet linking, auto-deduct on purchase, estimated vs actual cost comparison.
**Avoids pitfalls:** None specific — leverages existing transaction infrastructure.

### Phase 7: Investment Tracking
**Rationale:** Independent from shopping/budgets after the wallet system exists. Investment tracking is a core stated feature (not a v2 deferral) and requires its own data models, external API integration, and specialized calculations (XIRR).
**Delivers:** Investment CRUD (mutual funds + stocks) per wallet; NAV fetcher (mfapi.in) + stock price fetcher; portfolio views with per-fund/stock breakdown; gain/loss calculations (absolute + percentage); SIP tracking with debit date calendar; XIRR calculation with convergence guards.
**Addresses features:** Mutual fund tracking, stock tracking, SIP tracking, auto NAV/price fetch, portfolio view, XIRR calculation, investment gains/losses, investment privacy.
**Avoids pitfalls:** #13 (XIRR convergence — bounded Newton-Raphson + fallback to bisection), #19 (NAV staleness — show NAV date, market holiday awareness).

### Phase 8: Document Vault
**Rationale:** Independent from investments. Depends on sync (Phase 4) for file upload to Supabase Storage. Can be built in parallel with investments if needed.
**Delivers:** File upload (camera + gallery + file picker); local file caching; Supabase Storage upload via sync queue; image + PDF viewer; link documents to transactions; standalone documents with metadata; warranty expiry tracking with alerts.
**Addresses features:** Transaction-linked receipts, standalone documents, image + PDF support, warranty expiry alerts, document search, documents follow wallet privacy rules.
**Avoids pitfalls:** #17 (storage policies ≠ table RLS — mirror wallet-based privacy in bucket policies, UUID file paths).

### Phase 9: SMS Auto-Capture (Android)
**Rationale:** SMS parsing is Android-only, complex (diverse bank formats), and creates transactions — so all transaction + category infrastructure must be solid. It's last among core features because it's the highest-maintenance feature and benefits from a stable transaction pipeline.
**Delivers:** SMS reader via `telephony` package with last-processed timestamp; bank-specific parser registry (SBI, HDFC, ICICI, Axis, etc.); rule engine for merchant auto-categorization; draft transaction workflow for unknown merchants; ref number deduplication; user correction feedback loop.
**Addresses features:** SMS parsing for bank/UPI transactions, on-app-open backfill, transaction ref dedup, smart rules for auto-categorization, draft transactions for unknowns.
**Avoids pitfalls:** #9 (SMS format diversity — per-bank parser registry, graceful fallback), #18 (web crash — conditional imports, no-op web implementation), #20 (Android 13+ permissions — explain-before-request, handle denial gracefully).

### Phase 10: Analytics, Goals & Polish
**Rationale:** Analytics require rich transaction data (built up by now). Financial goals are motivational features that sit on top of wallets. Polish includes CI/CD, data export, settings, and deployment finalization.
**Delivers:** Deep analytics (category charts, date range comparisons, spending trends, budget vs actual); financial goals (shared + private) with progress tracking; settings screen; CSV/PDF export; CI/CD pipeline (GitHub Actions: tests → build web → deploy Vercel → build APK); Supabase keep-alive cron finalization.
**Addresses features:** Monthly/weekly/yearly summaries, category-wise charts, date range analytics, shared vs personal spending ratio, income vs expense cash flow, financial goals, data backup & restore, year-end summary.
**Avoids pitfalls:** #10 (free-tier limits — keep-alive cron deployed, 500MB DB monitoring).

### Phase Ordering Rationale

- **Foundation → Data → UI → Sync** follows the dependency graph exactly. You can't build UI without providers, you can't build providers without repositories, and sync without a data layer is meaningless.
- **Sync before feature phases (5-9)** because every feature needs sync working. Validating sync with simple transaction data is far easier than debugging sync after 10 tables and 50 queries exist.
- **Budgets before Shopping** because shopping auto-deduct needs budget-aware validation ("will this purchase exceed budget?").
- **Investments and Documents are independent** — can be parallelized or reordered without impact. Both depend only on the wallet system (Phase 2) and sync (Phase 4).
- **SMS last among core features** because it creates transactions (needs Phase 2), uses categories (needs Phase 5), and is Android-only with high maintenance burden. Building it last means the transaction pipeline is battle-tested.
- **Analytics last** because they aggregate from all other features. More data sources = richer analytics.

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 4 (Sync Engine):** Most complex component. Specific Drift isolate patterns, Supabase PostgREST batch upsert capabilities, retry/backoff strategies need investigation during planning.
- **Phase 7 (Investments):** XIRR implementation nuances, mfapi.in response format edge cases, stock price API reliability, and SIP date calculation need API-specific research.
- **Phase 9 (SMS Parsing):** Indian bank SMS format corpus collection, `telephony` package compatibility with Android 13+, regex pattern design for 10+ banks.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** Supabase setup + Flutter scaffold — well-documented quickstarts.
- **Phase 2 (Core Data):** Drift DAO pattern + Repository pattern — extensively documented in Drift docs.
- **Phase 3 (Core UI):** Standard Flutter screens + Riverpod wiring — established patterns.
- **Phase 5 (Budgets):** Standard CRUD + SUM queries — no novel patterns.
- **Phase 6 (Shopping Lists):** Standard CRUD with FK to transactions — straightforward.
- **Phase 8 (Document Vault):** Supabase Storage SDK + `image_picker` — documented in official quickstarts.
- **Phase 10 (Analytics):** `fl_chart` library + aggregation queries — well-documented.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All technologies verified via official docs, pricing pages, GitHub activity. Flutter + Drift + Supabase is a proven combination. |
| Features | HIGH | Competitor analysis covers 13+ apps (YNAB, Splitwise, CRED, ET Money, Groww, etc.). Feature dependencies mapped explicitly. |
| Architecture | HIGH | Offline-first + outbox sync + RLS is a well-documented pattern. Verified via Drift docs, Supabase RLS docs, Flutter architectural overview. |
| Pitfalls | HIGH | 20 pitfalls identified with specific prevention strategies. Top 7 critical pitfalls are universally documented in offline-first and financial software literature. |

**Overall confidence:** HIGH

### Gaps to Address

- **Stock price API reliability (LOW confidence):** NSE/BSE don't offer official free APIs. Public endpoints may change or get blocked. Need a reliable fallback (Yahoo Finance, Google Finance). Research during Phase 7 planning.
- **SMS format corpus:** No exhaustive, up-to-date corpus of Indian bank SMS formats exists publicly. Need to crowdsource real samples during Phase 9 development and build iteratively.
- **Supabase Edge Functions in Dart:** Edge Functions run Deno (TypeScript). Any complex server-side logic (e.g., atomic transfer RPC) must be written in TypeScript, not Dart. This is a minor friction point — the functions are small.
- **Drift Web performance at scale:** While Drift Web works, performance with 50K+ records on `sql.js` (IndexedDB backend) is undocumented. May need pagination strategies. Monitor during Phase 4.
- **Supabase 500MB limit:** With NAV history for 50+ MF schemes × 365 days × 5 years, plus transactions, the 500MB free-tier DB may fill faster than expected. Need a data retention/archival strategy if this becomes an issue.

## Sources

### Primary (HIGH confidence)
- Flutter architectural overview: https://docs.flutter.dev/resources/architectural-overview
- Drift documentation: https://drift.simonbinder.eu/
- Drift migrations & testing: https://drift.simonbinder.eu/Migrations/
- Drift web platform: https://drift.simonbinder.eu/platforms/web/
- Supabase RLS docs: https://supabase.com/docs/guides/database/postgres/row-level-security
- Supabase pricing: https://supabase.com/pricing
- Supabase Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter
- mfapi.in: https://www.mfapi.in/

### Secondary (MEDIUM confidence)
- Neon plans & pricing: https://neon.com/docs/introduction/plans
- Turso pricing: https://turso.tech/pricing
- XIRR Newton-Raphson convergence: numerical methods literature
- PowerSync pricing: https://www.powersync.com/pricing

### Tertiary (LOW confidence)
- NSE/BSE public stock endpoints: no official documentation; public accessibility may change
- Indian bank SMS format patterns: community knowledge, no authoritative reference

---
*Research completed: 2026-03-17*
*Ready for roadmap: yes*
