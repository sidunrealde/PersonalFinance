# Technology Stack

**Project:** Household Financial & Life Organizer
**Researched:** 2026-03-17

## Recommended Stack

### Architecture Philosophy: No Separate Backend

The single most impactful stack decision is **eliminating the backend server entirely**. Supabase provides PostgreSQL + Auth + Storage + auto-generated REST API (PostgREST) + Edge Functions. For a 2-user household app, adding a Python/FastAPI layer is unnecessary complexity and another free-tier to manage.

**Why this works:**
- PostgREST auto-generates CRUD APIs from your Postgres schema
- Row Level Security (RLS) enforces the Privacy Wall at the database level — no API middleware needed
- Edge Functions handle any custom logic (complex validations, data transformations)
- NAV/stock data fetched client-side from free APIs (mfapi.in) — no server-side cron needed
- Polling sync is just REST calls with `modified_at` filters

**Confidence: HIGH** — Verified via Supabase official docs, pricing page, Flutter SDK quickstart.

---

### Core Framework

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Flutter** | 3.41+ (latest stable) | Cross-platform UI framework | Single codebase → Android + Web. Dart compiles to native ARM (Android) and JavaScript/WASM (Web). Platform channels enable native SMS access. Best offline-first tooling via Drift. Impeller rendering engine for smooth 60fps financial charts. | HIGH |
| **Dart** | 3.7+ (latest stable) | Programming language | Null safety catches financial calculation bugs at compile time. Strong typing for decimal/money types. Isolates for background sync without blocking UI. | HIGH |

**Flutter wins over alternatives because:**
- **vs React Native:** Flutter Web is more mature than React Native Web. Drift (SQLite ORM) is best-in-class for offline-first in Flutter — nothing equivalent exists in RN. Single language (Dart) for everything vs JS + native bridges.
- **vs Kotlin Multiplatform:** KMP's web target (Kotlin/WASM) is experimental in 2026. Not production-ready for the web half of this app.

### Cloud Backend

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Supabase** (PostgreSQL) | Latest | Database, Auth, Storage, API | PostgreSQL RLS maps directly to wallet-based Privacy Wall. PostgREST auto-generates REST API. Free tier: 500MB DB, 50K MAU, 1GB file storage, 5GB bandwidth. First-class Flutter SDK. | HIGH |
| **Supabase Auth** | Included | Authentication | Email/password auth built-in. JWT tokens carry user_id used in RLS policies. `auth.uid()` function available directly in SQL policies. Zero custom auth code. | HIGH |
| **Supabase Storage** | Included | Document vault | File upload/download with RLS-like bucket policies. Free tier includes 1GB storage. Supports images + PDFs for receipts and manuals. | HIGH |
| **Supabase Edge Functions** | Included (Deno) | Custom server logic | 500K invocations/month free. Use for complex validations, batch operations, or any logic that can't be expressed in SQL/RLS. | MEDIUM |

**Free Tier Caveat:** Supabase free projects pause after 1 week of inactivity (max 2 active free projects). See **"Supabase Pausing: Mitigation & Alternatives"** section below for the recommended keep-alive strategy and fallback options.

### Local Database (Offline-First)

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Drift** | 2.32.0 | Local SQLite ORM | Type-safe SQL queries at compile time. Reactive streams (`watch()`) for auto-updating UI. Built-in schema migrations. DAOs for clean code organization. Isolate support for background DB operations. 3.2K GitHub stars, 169 contributors, actively maintained (last release: March 2026). Cross-platform: works on Android, Web, and desktop. | HIGH |
| **drift_flutter** | Latest | Flutter-specific Drift bindings | Provides `DriftDatabase` with platform-appropriate SQLite backend. Handles native SQLite on Android, sql.js on Web. | HIGH |
| **sqlite3_flutter_libs** | Latest | Native SQLite for Android | Bundles latest SQLite binary. Required by Drift on mobile. | HIGH |

**Why Drift over alternatives:**
- Financial data is inherently relational (transactions → wallets → users → households, categories, goals). SQLite with Drift gives you JOINs, aggregations (`SUM`, `GROUP BY` for category totals), and complex queries that NoSQL can't match.
- Reactive streams mean your budget widget auto-updates when a new transaction syncs.
- Type-safe code generation catches errors like wrong column references at compile time, not at runtime with your money.

### State Management

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **Riverpod** | 2.6+ | State management & DI | Compile-time safe providers. No `BuildContext` dependency (can use in services, sync logic). Built-in `AsyncValue` for loading/error/data states. `autoDispose` prevents memory leaks. Testable without widget tree. | HIGH |
| **flutter_riverpod** | 2.6+ | Flutter integration for Riverpod | Provides `ConsumerWidget`, `ConsumerStatefulWidget`, `ref.watch`/`ref.read`. | HIGH |

### Routing

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **go_router** | 14+ | Declarative routing | Official Flutter-endorsed router. Deep link support (needed for auth callbacks). Redirect guards for auth state. Web URL support built-in. | HIGH |

### Investment Data APIs

| Technology | Version | Purpose | Why | Confidence |
|------------|---------|---------|-----|------------|
| **mfapi.in** | REST API | Mutual fund NAV data | 100% free, no auth required, no rate limiting. 10K+ Indian mutual fund schemes. 5+ years of historical NAV data. Updated 6x daily. JSON responses. | HIGH |
| **NSE/BSE public endpoints** | REST | Stock price data | Free market data available through exchange websites. No official API, but market data endpoints are publicly accessible. Consider Google Finance or Yahoo Finance fallback. | LOW |

**NAV fetching strategy:** Client-side, on app open. No server-side cron job needed.
1. App opens → check if NAV data is stale (>24h)
2. If stale, fetch from mfapi.in directly from Flutter app
3. Update local Drift DB
4. Sync to Supabase on next sync cycle
5. Both household users get same NAV data via sync

This eliminates all backend infrastructure for NAV fetching and works offline (uses last cached NAV).

---

## Supporting Libraries

### Network & Sync

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **supabase_flutter** | ^2.0.0 | Supabase client SDK | All Supabase interactions: auth, DB queries, storage uploads. Official first-class Flutter SDK. |
| **dio** | ^5.7+ | HTTP client | For external API calls (mfapi.in, stock prices). Interceptors for retry logic. Not needed for Supabase calls (SDK handles those). |
| **connectivity_plus** | ^6.1+ | Network status | Detect online/offline state. Trigger sync when connection restored. Drive UI indicators (sync status). |

### SMS Parsing (Android Only)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **telephony** | ^0.2.0+ | Read SMS inbox | Access Android SMS content provider via platform channels. Read messages since last processed timestamp. No background service — only on app open. |
| **Custom Dart regex engine** | N/A | Parse bank SMS | Indian bank SMS formats (SBI, HDFC, ICICI, etc.) with transaction amounts, reference numbers, merchant names. Build a rule-based parser with regex patterns per bank. |

### UI & Charts

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **fl_chart** | ^0.70+ | Financial charts | Category pie charts, spending bar charts, portfolio line charts, budget progress. Customizable, performant, actively maintained. |
| **flutter_local_notifications** | ^18+ | Notifications | Budget alerts, recurring transaction reminders, SIP date alerts. Works on Android with scheduled notifications. |
| **intl** | ^0.19+ | Formatting | Indian Rupee formatting (₹), date formatting, number formatting to 4 decimal places (mutual fund units). |

### Document Vault

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **image_picker** | ^1.1+ | Camera/gallery capture | Capture receipt photos from camera or pick from gallery. |
| **file_picker** | ^8.1+ | File selection | Pick PDF documents (manuals, warranties) from device storage. |
| **flutter_pdfview** | ^1.3+ | PDF viewer | View stored PDF documents within the app. |

### Data & Code Generation

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **freezed** | ^2.5+ | Immutable data classes | Generate immutable models with `copyWith`, `==`, `hashCode`. Use for domain models (Transaction, Wallet, Investment). |
| **json_serializable** | ^6.8+ | JSON serialization | Supabase returns JSON — auto-generate `fromJson`/`toJson`. |
| **uuid** | ^4.5+ | UUID generation | Generate client-side UUIDs for offline-created records. Prevents ID collisions when syncing. |

### Storage & Utilities

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **shared_preferences** | ^2.3+ | Key-value storage | User settings, last sync timestamp, last SMS processed timestamp. Not for data — only small preferences. |
| **path_provider** | ^2.1+ | File system paths | Get app document directory for local file cache (downloaded receipts/PDFs). |

### Dev Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| **drift_dev** | ^2.32.0 | Drift code generator |
| **build_runner** | ^2.4+ | Dart build system — runs code generators |
| **freezed_annotation** | ^2.4+ | Annotations for freezed |
| **json_annotation** | ^4.9+ | Annotations for json_serializable |
| **flutter_test** | SDK | Widget testing |
| **mockito** | ^5.4+ | Mock generation for unit tests |
| **integration_test** | SDK | End-to-end testing |
| **flutter_lints** | ^5.0+ | Lint rules |

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| **Framework** | Flutter | React Native | RN Web less mature. No Drift equivalent for offline-first SQLite. JS bridge overhead for financial calculations. Two ecosystems (JS + native) vs one (Dart). |
| **Framework** | Flutter | Kotlin Multiplatform | Web target (Kotlin/WASM) is experimental. Android-only would be fine, but web support is the blocker. |
| **Backend** | Supabase | Firebase/Firestore | Firestore is NoSQL — can't do relational JOINs for financial data. No Row Level Security equivalent. Firestore security rules are less expressive than PostgreSQL RLS. Vendor lock-in to Google. |
| **Backend** | Supabase | PocketBase | PocketBase docs explicitly say "NOT recommended for production critical applications yet" (pre-v1.0). No PostgreSQL-grade RLS. Would need self-hosting. Single-file SQLite backend doesn't scale to the complexity of financial data with privacy walls. |
| **Backend** | Supabase | Separate FastAPI + DB | Unnecessary complexity for 2 users. Extra free-tier to manage (Render/Railway). PostgREST already generates the API you'd write manually. Doubles the deployment surface. |
| **Local DB** | Drift (SQLite) | Hive | Hive is key-value NoSQL. Can't do `SELECT SUM(amount) FROM transactions WHERE wallet_id = ? AND category_id = ? GROUP BY month`. Financial data demands relational queries. |
| **Local DB** | Drift (SQLite) | Isar | Isar development stalled in 2024. NoSQL model. Less suitable for relational financial data. |
| **Local DB** | Drift (SQLite) | ObjectBox | NoSQL. Same relational limitation as Hive/Isar. Also adds native binary dependency. |
| **Sync** | Custom polling | PowerSync | PowerSync free tier: 50 concurrent connections, 500MB, pauses after 1 week. Pro: $49/month — violates free-tier constraint. For 2 users, custom polling is trivially simple and costs nothing. |
| **Sync** | Custom polling | Supabase Realtime (WebSocket) | PROJECT.md explicitly chose polling over WebSocket. Simpler architecture. No connection management. Free tier limits (200 concurrent, 2M messages/month) are generous but irrelevant since we don't need real-time push. |
| **State** | Riverpod | BLoC/Cubit | More boilerplate (Events, States, Blocs) for every feature. Riverpod achieves the same reactive state with less ceremony. BLoC is better for very large teams — overkill for a 2-person household app. |
| **State** | Riverpod | Provider | Provider is the predecessor to Riverpod. Riverpod fixes Provider's limitations (no `BuildContext` needed, compile-time safety, better testing). Provider's author (Remi Rousselet) created Riverpod as its successor. |
| **State** | Riverpod | GetX | Mixes state, routing, DI, HTTP in one package. Poor separation of concerns. Difficult to test. Community consensus has moved away from GetX. |

---

## What NOT to Use

### Firebase/Firestore — Wrong Data Model
Firestore's document/collection model cannot express `SELECT t.*, c.name FROM transactions t JOIN categories c ON t.category_id = c.id WHERE t.wallet_id = ? ORDER BY t.timestamp DESC`. You'd denormalize everything, making the Privacy Wall enforcement fragile and budget calculations client-side.

### Hive/Isar/ObjectBox — NoSQL is Wrong for Finance
Financial data is inherently relational: transactions belong to wallets, wallets belong to users and households, categories are shared, goals reference wallets, shopping list items create transactions. NoSQL forces you to denormalize and manually maintain consistency. SQLite with Drift gives you ACID transactions, foreign keys, and `SUM(amount) GROUP BY category` out of the box.

### Separate Backend Server (FastAPI/Express/etc.)
Supabase's PostgREST already generates type-safe REST APIs from your schema. RLS enforces authorization at the DB level. Edge Functions handle custom logic. Adding a backend server means: another deployment, another free-tier to manage, another codebase to maintain, duplicated authorization logic, and a SPOF between your app and your database.

### GetX
Despite its popularity in tutorials, the Flutter community has largely moved away from GetX. It violates separation of concerns by bundling state management, routing, dependency injection, and HTTP in one opinionated package. Testing is difficult, and it encourages patterns that become unmaintainable.

### WebSocket Sync (Supabase Realtime)
For 2 users, WebSocket sync adds connection management complexity for negligible benefit. Polling every 30 seconds gives "near real-time" that's indistinguishable from WebSocket for a household finance app. The PROJECT.md explicitly chose this.

### PowerSync
Excellent sync engine, but at $49/month for production use, it violates the free-tier constraint. For 2 users with last-write-wins, a simple sync queue in Drift + Supabase REST is ~200 lines of Dart, not a monthly subscription.

---

## Sync Architecture (Custom Polling)

Since this is the most critical non-obvious decision, here's the approach:

### Local-First Write Path
1. All writes go to local Drift DB first (instant, works offline)
2. Each write creates a `SyncQueueEntry` with `{table, record_id, operation, timestamp}`
3. When online, a periodic timer (every 30s) processes the queue
4. For each entry: push to Supabase via REST → on success, remove from queue
5. On failure: retry with exponential backoff

### Remote-to-Local Sync Path
1. Each table has a `server_updated_at` timestamp column
2. On sync, query Supabase: `SELECT * FROM transactions WHERE updated_at > {last_sync_timestamp} AND wallet_id IN ({user's visible wallets})`
3. Upsert results into local Drift DB
4. RLS on Supabase ensures you only ever receive data you're authorized to see

### Conflict Resolution
- **Last-write-wins** based on `updated_at` timestamp
- For 2 users with low concurrency, conflicts are rare
- The only realistic conflict: both users edit the same shared transaction simultaneously, which is an edge case handled gracefully by LWW

---

## Hosting & Deployment

| Service | Tier | Purpose | Limits |
|---------|------|---------|--------|
| **Supabase** | Free | Database, Auth, Storage, API, Edge Functions | 500MB DB, 50K MAU, 1GB storage, 5GB bandwidth, 500K Edge Function invocations |
| **Vercel** | Hobby (Free) | Flutter Web hosting (static) | 100GB bandwidth/month, unlimited deployments |
| **GitHub Actions** | Free | CI/CD (tests + builds) + Supabase keep-alive cron | 2,000 minutes/month for private repos |
| **GitHub** | Free | Source control | Private repos, unlimited |

**Deployment Flow:**
1. Push to `main` → GitHub Actions runs Flutter analyzer + tests
2. On success → Build Flutter Web (`flutter build web --wasm`) → Deploy to Vercel
3. On success → Build Android APK (`flutter build apk --release`)
4. Supabase migrations applied via CLI in the pipeline

---

## Supabase Pausing: Mitigation & Alternatives

Supabase free-tier projects pause after **1 week of inactivity** (must be manually unpaused, max 2 active free projects). For a daily-use finance app, this is a real concern — vacations, phone switches, or simply forgetting to open the app for a week could cause cloud sync to go down.

### Recommended: GitHub Actions Keep-Alive Cron (FREE)

The simplest, zero-cost solution: a scheduled GitHub Actions workflow that pings the Supabase project every 5 days.

```yaml
# .github/workflows/supabase-keepalive.yml
name: Supabase Keep-Alive
on:
  schedule:
    - cron: '0 6 */5 * *'  # Every 5 days at 6 AM UTC
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - run: |
          curl -s -o /dev/null -w "%{http_code}" \
            "${{ secrets.SUPABASE_URL }}/rest/v1/?apikey=${{ secrets.SUPABASE_ANON_KEY }}"
```

**Why this is the best option:**
- Zero cost — GitHub Actions free tier (2,000 min/month) easily covers ~6 pings
- Zero architecture changes — everything else stays the same
- Dead simple — a single lightweight HTTP request, no auth tokens needed beyond the public anon key
- The project never pauses because Supabase detects API activity

**Confidence: HIGH** — This is a widely-used community pattern; Supabase pausing is triggered by absence of API calls, any API call prevents it.

### Alternative 1: Neon Postgres (if moving away from Supabase)

**Neon** (neon.com) is a serverless PostgreSQL provider acquired by Databricks. Its "scale to zero" is fundamentally different from Supabase's "project pausing":

| Aspect | Supabase Free | Neon Free |
|--------|---------------|-----------|
| Price | $0 | $0, no credit card |
| DB storage | 500 MB | 0.5 GB/project |
| Projects | 2 active | **100 projects** |
| Inactivity behavior | **Project pauses after 1 week**, manual unpause | **Compute scales to zero after 5 min**, auto-wakes in ~350ms on next query |
| Compute | Always-on while active | 100 CU-hours/month/project (~3 hrs/day at 1 CU) |
| Auth | GoTrue (50K MAU) | Neon Auth / Better Auth (60K MAU) |
| REST API | PostgREST (auto-generated) | ❌ Not included |
| File Storage | 1 GB | ❌ Not included |
| Edge Functions | 500K invocations | ❌ Not included |
| RLS | ✅ PostgreSQL RLS | ✅ PostgreSQL RLS |
| Network transfer | 5 GB | 5 GB |
| Connection pooling | Via Supavisor | pgBouncer (up to 10K connections) |

**Neon's key advantage:** Zero-downtime scale-to-zero. The compute suspends after 5 min idle and **automatically wakes in ~350ms** on the next query. Projects are never "paused" — they're just sleeping.

**Neon's gap:** It's just a database + auth. You'd lose PostgREST (auto REST API), Storage (document vault), and Edge Functions. To replace those:
- **API:** Build a lightweight REST layer with Dart Shelf + Vercel Serverless, or call Neon directly via PostgreSQL wire protocol (not recommended from mobile)
- **Storage:** Cloudflare R2 (10GB free, S3-compatible) or Backblaze B2 (10GB free)
- **Auth:** Neon Auth covers this (60K MAUs, built on Better Auth)

**Verdict:** Neon is a genuinely better PostgreSQL host for never-pause, but switching means rebuilding the API and storage layers. Only worth it if the keep-alive cron is unacceptable for some reason.

**Source:** https://neon.com/docs/introduction/plans (verified March 2026) — **HIGH confidence**

### Alternative 2: Turso (SQLite-family, interesting but niche)

| Aspect | Turso Free |
|--------|-----------|
| Price | $0 |
| Storage | 5 GB |
| Databases | 100 |
| Reads | 500M rows/month |
| Writes | 10M rows/month |
| Sync bandwidth | 3 GB/month |
| Pausing | **No mention of inactivity pausing** |
| Engine | libSQL (SQLite fork) |

**Interesting angle:** Turso uses libSQL, a SQLite fork. Since the app already uses Drift (SQLite) locally, there's a compelling future path: SQLite-to-SQLite sync via Turso's embedded replicas. This could simplify the sync architecture significantly.

**Why NOT now:** No built-in auth, no storage, no REST API, and the SQLite-to-SQLite sync story with Drift isn't proven yet. Would require significant architecture work.

**Source:** https://turso.tech/pricing (verified March 2026) — **MEDIUM confidence** (no explicit documentation on whether projects pause)

### Alternative 3: Fly.io (Not free anymore)

Fly.io discontinued its free hobby tier. New accounts are pay-as-you-go: minimum ~$1.94/month for a shared-cpu-1x 256MB VM, plus ~$2/month for unmanaged Postgres. **Violates the free-tier constraint.** Not recommended.

**Source:** https://fly.io/docs/about/pricing/ (verified March 2026) — **HIGH confidence**

### Recommendation

**Use Supabase + keep-alive cron.** It's the simplest solution that preserves the entire architecture (Auth, PostgREST, Storage, RLS, Edge Functions) at zero cost. The cron is a one-time 10-line setup.

If Supabase changes their free-tier policy in the future to detect and block keep-alive pings, Neon is the strongest fallback — but it would require building an API layer and moving file storage elsewhere.

---

## Installation

```bash
# Create Flutter project
flutter create --org com.household personal_finance
cd personal_finance

# Core dependencies
flutter pub add supabase_flutter drift drift_flutter sqlite3_flutter_libs
flutter pub add flutter_riverpod go_router dio connectivity_plus
flutter pub add intl uuid shared_preferences path_provider

# UI & Charts
flutter pub add fl_chart flutter_local_notifications
flutter pub add image_picker file_picker flutter_pdfview

# Data modeling
flutter pub add freezed_annotation json_annotation

# SMS (Android only)
flutter pub add telephony

# Dev dependencies
flutter pub add --dev drift_dev build_runner freezed json_serializable
flutter pub add --dev mockito build_runner flutter_lints

# Run code generation
dart run build_runner build --delete-conflicting-outputs
```

---

## Sources

- Flutter architectural overview: https://docs.flutter.dev/resources/architectural-overview (Flutter 3.41, page updated 2025-12-08) — **HIGH confidence**
- Drift GitHub repository: https://github.com/simolus3/drift (v2.32.0, March 2026) — **HIGH confidence**
- Drift documentation: https://drift.simonbinder.eu/ — **HIGH confidence**
- Supabase pricing: https://supabase.com/pricing (verified March 2026) — **HIGH confidence**
- Supabase RLS documentation: https://supabase.com/docs/guides/database/postgres/row-level-security — **HIGH confidence**
- Supabase Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter — **HIGH confidence**
- PowerSync pricing: https://www.powersync.com/pricing (verified March 2026) — **HIGH confidence**
- PowerSync docs: https://docs.powersync.com/ — **HIGH confidence**
- PocketBase docs: https://pocketbase.io/docs/ (v0.36.7, "NOT recommended for production critical applications yet") — **HIGH confidence**
- mfapi.in: https://www.mfapi.in/ (free, no auth, 10K+ schemes, updated 6x daily) — **HIGH confidence**
- Render pricing: https://render.com/pricing (verified March 2026, free Postgres has 30-day limit) — **HIGH confidence**
- Neon plans & pricing: https://neon.com/docs/introduction/plans, https://neon.com/pricing (Free: 100 projects, 0.5GB/project, 100 CU-hours, scale-to-zero in 5min, auto-wake ~350ms) — **HIGH confidence**
- Turso pricing: https://turso.tech/pricing (Free: 100 DBs, 5GB, 500M reads, 10M writes, libSQL) — **MEDIUM confidence**
- Fly.io pricing: https://fly.io/docs/about/pricing/ (no free tier for new accounts, pay-as-you-go only) — **HIGH confidence**
