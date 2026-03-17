# Phase 1: Foundation & Schema - Research

**Researched:** 2026-03-17
**Domain:** Flutter + Supabase + Drift project scaffolding, PostgreSQL schema, RLS, auth
**Confidence:** HIGH

## Summary

Phase 1 establishes the entire infrastructure backbone for a two-person household financial app. The core deliverables are: (1) a Flutter project that builds on Android + Web, (2) a Supabase project with PostgreSQL schema for **Phase 1 active tables** (households, wallets, categories, invites, auth profiles) plus **all future-feature tables** defined in Drift locally, (3) email/password auth with custom household invite system, (4) RLS policies enforcing the Privacy Wall, and (5) SQL assertion tests proving private data isolation.

The biggest risk in this phase is getting the schema right — every future phase builds on these tables. The second risk is RLS policy correctness; a gap means the Privacy Wall is broken from day one. Both are mitigated by SQL test assertions and the auto-RLS event trigger.

**Primary recommendation:** Build Supabase schema with CLI migrations (version-controlled SQL files). Define ALL tables in Drift (local SQLite mirror) upfront. Use the auto-RLS event trigger from the first migration. Write pgTAP-style SQL tests to prove privacy isolation before any feature code.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Magic link invite: first user creates household during guided setup, generates a magic link to share with partner (email/WhatsApp)
- Link expires after 7 days; first user can regenerate anytime
- Second user clicks link → signs up → auto-joins the household
- Leave and re-invite allowed: either member can leave; the other can invite a new partner
- Household is user-named during onboarding (e.g., "The Patels")
- Full guided setup after signup: household name, invite partner step, initial wallet creation, sample default categories
- Onboarding wizard walks through setup before landing on dashboard
- Fixed 3 wallets per household: one shared wallet + one private wallet per user
- No custom wallets — the three wallets are auto-created when household is formed
- Shared wallet is visible to both members; private wallets are strictly isolated
- Preset categories installed on every new wallet: Food, Transport, Shopping, Bills, Health, Entertainment, Education, Miscellaneous
- Users can rename, add, or remove categories later (Phase 2+ handles CRUD)
- Full schema upfront: create ALL tables for ALL future features in Phase 1
- RLS enabled on privacy-sensitive tables only
- User-based RLS: user_id on every privacy-sensitive row
- Auto-enable trigger: any new table automatically gets a deny-all RLS policy
- SQL assertion tests for Privacy Wall verification
- Integer paise for ALL monetary columns
- Separate updated_at and synced_at columns
- Client-side UUIDs for all primary keys
- transfer_ref UUID column for atomic wallet transfers

### Claude's Discretion
- JWT token refresh strategy and session duration
- Supabase Edge Function usage vs client-side logic
- Specific Drift schema migration approach
- Flutter project structure (feature-first vs layer-first)
- go_router route hierarchy

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| AUTH-01 | User can sign up with email and password | Supabase Auth `signUp()` with email/password — §6 Auth Flow |
| AUTH-02 | User can log in and stay logged in across sessions (JWT refresh) | Supabase session persistence + `onAuthStateChange` listener — §6 Auth Flow |
| AUTH-03 | User can log out from any screen | Supabase Auth `signOut()` — §6 Auth Flow |
| AUTH-04 | User can create or join a household via invite link/code | Custom invite system with `household_invites` table + magic link — §6 Auth Flow |
| AUTH-05 | All data encrypted in transit (TLS) and sensitive fields at rest | Supabase enforces TLS by default; pgcrypto for sensitive fields — §6 Auth Flow |
| WALL-01 | Each household has shared + private wallets, auto-created on signup | Wallet auto-creation via Supabase DB trigger or post-signup logic — §3 Schema, §7 Onboarding |
| WALL-02 | Private wallet data NEVER visible to other member — enforced at DB (RLS), repo, UI | RLS policies + `visible_wallet_ids()` helper function — §5 RLS |
| PLAT-05 | Single codebase builds Android + Web | Flutter project with `drift_flutter` cross-platform DB — §1 Flutter Setup |
</phase_requirements>

---

## 1. Flutter Project Setup

### Project Structure Decision: Hybrid (Layer + Feature)

**Recommendation:** Use a **hybrid structure** — shared infrastructure in layer folders (`core/`, `data/`, `services/`, `providers/`) and UI in feature folders (`features/auth/`, `features/dashboard/`, etc.). This matches the architecture from project-level research.

```
personal_finance/
├── lib/
│   ├── main.dart                      # Entry point, Supabase.initialize()
│   ├── app.dart                       # MaterialApp.router + ProviderScope
│   │
│   ├── core/                          # Shared utilities
│   │   ├── constants/
│   │   │   ├── app_constants.dart     # Sync intervals, paise multiplier
│   │   │   └── supabase_tables.dart   # Table name string constants
│   │   ├── extensions/                # Dart extensions
│   │   ├── errors/                    # Custom exceptions
│   │   ├── utils/
│   │   │   ├── money.dart             # Money value object (int paise)
│   │   │   └── date_utils.dart
│   │   └── theme/
│   │       └── app_theme.dart         # Material 3 theme
│   │
│   ├── data/                          # Data layer
│   │   ├── database/
│   │   │   ├── app_database.dart      # @DriftDatabase class
│   │   │   ├── app_database.g.dart    # Generated
│   │   │   ├── tables/               # All Drift table definitions
│   │   │   └── daos/                 # Drift DAOs
│   │   ├── models/                   # Freezed data classes
│   │   └── repositories/            # Privacy-enforcing access
│   │
│   ├── services/                     # Business logic
│   │   ├── auth/
│   │   │   └── auth_service.dart
│   │   └── sync/                     # (Phase 4)
│   │
│   ├── providers/                    # Riverpod providers
│   │   ├── auth_providers.dart
│   │   ├── database_providers.dart
│   │   └── wallet_providers.dart
│   │
│   ├── features/                     # Feature-based UI
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   │   ├── login_screen.dart
│   │   │   │   ├── signup_screen.dart
│   │   │   │   └── onboarding_screen.dart
│   │   │   └── widgets/
│   │   └── dashboard/
│   │       ├── screens/
│   │       └── widgets/
│   │
│   └── routing/
│       └── app_router.dart           # GoRouter + auth redirect guards
│
├── supabase/                         # Supabase CLI project
│   ├── config.toml
│   ├── migrations/
│   │   ├── 00000000000000_init_schema.sql
│   │   ├── 00000000000001_rls_policies.sql
│   │   ├── 00000000000002_helper_functions.sql
│   │   └── 00000000000003_seed_triggers.sql
│   └── tests/
│       └── rls_privacy_test.sql      # pgTAP tests
│
├── test/                             # Dart/Flutter tests
├── web/                              # Flutter web assets
├── android/                          # Android platform
├── pubspec.yaml
├── analysis_options.yaml
└── .env                              # Supabase URL + anon key (gitignored)
```

**Confidence: HIGH** — Matches the architecture research and is the standard pattern for production Flutter apps of this scale.

### Build Configuration

**Android:** Standard Flutter Android build. Requires `minSdkVersion 21` (Android 5.0+) for Supabase and Drift compatibility. Set in `android/app/build.gradle`.

**Web:** Requires WASM build for Drift: `flutter build web --wasm`. Must serve with COOP/COEP headers for optimal Drift web storage (OPFS). For dev, `flutter run -d chrome` works without headers but uses slower IndexedDB fallback.

### pubspec.yaml Dependencies (Phase 1 only)

```yaml
name: personal_finance
description: Household financial & life organizer
publish_to: 'none'
version: 0.1.0

environment:
  sdk: ^3.7.0

dependencies:
  flutter:
    sdk: flutter

  # Supabase
  supabase_flutter: ^2.8.0

  # Local database (offline-first)
  drift: ^2.22.0
  drift_flutter: ^0.2.4
  sqlite3_flutter_libs: ^0.5.28

  # State management
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1

  # Routing
  go_router: ^14.8.0

  # Data modeling
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

  # Utilities
  uuid: ^4.5.1
  intl: ^0.19.0
  shared_preferences: ^2.3.4
  flutter_dotenv: ^5.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  drift_dev: ^2.22.0
  build_runner: ^2.4.14
  freezed: ^2.5.7
  json_serializable: ^6.9.0
  riverpod_generator: ^2.6.3
  custom_lint: ^0.7.0
  riverpod_lint: ^2.6.3
  mockito: ^5.4.5
  build_verify: ^3.1.0
```

> **Note on versions:** These are based on latest stable releases as of March 2026. Pin exact versions after first `flutter pub get` succeeds. The `drift` and `drift_flutter` version should match `drift_dev`.

### Environment Configuration

Use `flutter_dotenv` for environment variables:

```dart
// .env (gitignored)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key

// main.dart
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const ProviderScope(child: MyApp()));
}
```

**Alternative:** Use `--dart-define` for build-time env injection (better for CI):
```bash
flutter run --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
```

**Confidence: HIGH** — Verified via Context7 supabase_flutter docs: `Supabase.initialize()` is the official initialization pattern.

---

## 2. Supabase Configuration

### Supabase CLI Setup

```bash
# Install Supabase CLI (requires npm)
npm install -g supabase

# Initialize in project root
supabase init

# This creates:
# supabase/
# ├── config.toml
# ├── migrations/
# ├── functions/
# └── tests/

# Link to remote project (after creating on supabase.com)
supabase login
supabase link --project-ref <your-project-ref>

# Start local dev environment (requires Docker)
supabase start

# This spins up local PostgreSQL, Auth, Storage, PostgREST — full Supabase stack
# Local URLs printed to console (Studio at localhost:54323)
```

### Migration Workflow

```bash
# Create a new migration
supabase migration new init_schema
# Creates: supabase/migrations/<timestamp>_init_schema.sql

# Apply migrations to local
supabase db reset  # destructive — recreates from all migrations

# Push migrations to remote
supabase db push

# Diff local vs remote (useful for catching drift)
supabase db diff
```

**Key config.toml settings:**
```toml
[auth]
site_url = "http://localhost:3000"
enable_signup = true

[auth.email]
enable_signup = true
double_confirm_changes = true
enable_confirmations = false  # Disable for local dev, enable in production

[db]
major_version = 15  # Postgres 15 — needed for security_invoker views
```

### Supabase Flutter SDK Initialization

From Context7 docs, `supabase_flutter` v2 behavior:
- `Supabase.initialize()` returns **immediately** after retrieving session from local storage (does NOT await token refresh)
- Session may be expired at initialization — check `session.isExpired` or listen to `onAuthStateChange`
- The SDK handles token refresh automatically in background

```dart
// Recommended initialization pattern
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL']!,
  anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,  // More secure for mobile
  ),
);

final supabase = Supabase.instance.client;
```

**Confidence: HIGH** — Verified via Context7 `/websites/supabase_reference_dart`.

---

## 3. Database Schema Design

### Design Principles
- **UUID primary keys** — client-generated via `uuid` package (offline creation)
- **Integer paise** — all monetary values as `bigint` (₹500.00 = 50000)
- **Timestamp discipline** — `created_at`, `updated_at` (client-set), `server_updated_at` (DB trigger), `synced_at` (sync engine)
- **Soft deletes** — `deleted_at` nullable timestamp on all synced tables (enables undo + sync)
- **wallet_id / user_id** — on every privacy-sensitive row for RLS
- **household_id** — on shared-scope tables

### Phase 1 Active Tables (Detailed)

These tables are created in Supabase AND actively used in Phase 1:

```sql
-- =================================================================
-- Migration 001: Core Schema (Phase 1 Active Tables)
-- =================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pgtap";  -- for RLS tests

-- -------------------------------------------------------
-- profiles: extends auth.users with app-specific data
-- -------------------------------------------------------
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL DEFAULT '',
  household_id UUID,  -- FK added after households table
  onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- -------------------------------------------------------
-- households: user-named household (e.g., "The Patels")
-- -------------------------------------------------------
CREATE TABLE public.households (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Add FK from profiles to households
ALTER TABLE public.profiles
  ADD CONSTRAINT fk_profiles_household
  FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE SET NULL;

-- -------------------------------------------------------
-- household_members: tracks who's in which household
-- -------------------------------------------------------
CREATE TABLE public.household_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at TIMESTAMPTZ,  -- NULL = active member
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(household_id, user_id)
);

-- -------------------------------------------------------
-- household_invites: custom magic link invite system
-- -------------------------------------------------------
CREATE TABLE public.household_invites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  invited_by UUID NOT NULL REFERENCES auth.users(id),
  invite_code TEXT NOT NULL UNIQUE,  -- short alphanumeric code
  invite_token UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),  -- for magic link URL
  expires_at TIMESTAMPTZ NOT NULL,  -- 7 days from creation
  accepted_by UUID REFERENCES auth.users(id),
  accepted_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invites_token ON public.household_invites(invite_token)
  WHERE accepted_at IS NULL AND revoked_at IS NULL;
CREATE INDEX idx_invites_code ON public.household_invites(invite_code)
  WHERE accepted_at IS NULL AND revoked_at IS NULL;

-- -------------------------------------------------------
-- wallets: 3 per household (1 shared + 2 private)
-- -------------------------------------------------------
CREATE TABLE public.wallets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id),  -- NULL for shared wallet
  wallet_type TEXT NOT NULL CHECK (wallet_type IN ('shared', 'private')),
  name TEXT NOT NULL,  -- "Shared Wallet", "My Wallet"
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_wallets_household ON public.wallets(household_id);
CREATE INDEX idx_wallets_user ON public.wallets(user_id) WHERE user_id IS NOT NULL;

-- -------------------------------------------------------
-- wallet_categories: per-wallet categories
-- -------------------------------------------------------
CREATE TABLE public.wallet_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  icon TEXT,  -- emoji or icon name
  color TEXT,  -- hex color
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_income BOOLEAN NOT NULL DEFAULT false,  -- false = expense, true = income
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,

  UNIQUE(wallet_id, name, is_income)
);

CREATE INDEX idx_categories_wallet ON public.wallet_categories(wallet_id);
```

### Future-Feature Tables (Supabase — created in Phase 1 but populated later)

These tables are created in Supabase migrations to avoid complex future migrations. They sit empty until their respective phases activate them:

```sql
-- =================================================================
-- Migration 002: Future Feature Tables (empty until activated)
-- =================================================================

-- -------------------------------------------------------
-- transactions: income/expense records (Phase 2)
-- -------------------------------------------------------
CREATE TABLE public.transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.wallet_categories(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount_paise BIGINT NOT NULL,  -- integer paise (₹500.00 = 50000)
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  note TEXT,
  transaction_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  transfer_ref UUID,  -- links paired transfer transactions
  split_ref UUID,  -- links split transaction parts
  is_recurring_instance BOOLEAN NOT NULL DEFAULT false,
  recurring_transaction_id UUID,  -- FK added after recurring_transactions
  is_draft BOOLEAN NOT NULL DEFAULT false,  -- for SMS auto-capture drafts
  sms_ref TEXT,  -- SMS reference number for dedup
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  synced_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_txn_wallet ON public.transactions(wallet_id);
CREATE INDEX idx_txn_user ON public.transactions(user_id);
CREATE INDEX idx_txn_date ON public.transactions(transaction_date DESC);
CREATE INDEX idx_txn_category ON public.transactions(category_id);
CREATE INDEX idx_txn_transfer ON public.transactions(transfer_ref) WHERE transfer_ref IS NOT NULL;
CREATE INDEX idx_txn_split ON public.transactions(split_ref) WHERE split_ref IS NOT NULL;
CREATE INDEX idx_txn_sms_ref ON public.transactions(sms_ref) WHERE sms_ref IS NOT NULL;

-- -------------------------------------------------------
-- transaction_presets: quick-add presets (Phase 3)
-- -------------------------------------------------------
CREATE TABLE public.transaction_presets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  category_id UUID REFERENCES public.wallet_categories(id) ON DELETE SET NULL,
  name TEXT NOT NULL,  -- "Morning Coffee"
  amount_paise BIGINT NOT NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- -------------------------------------------------------
-- budgets: monthly per-category budget limits (Phase 5)
-- -------------------------------------------------------
CREATE TABLE public.budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.wallet_categories(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  month_year TEXT NOT NULL,  -- '2026-03' format for easy querying
  limit_paise BIGINT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,

  UNIQUE(wallet_id, category_id, month_year)
);

-- -------------------------------------------------------
-- recurring_transactions: auto-repeat rules (Phase 5)
-- -------------------------------------------------------
CREATE TABLE public.recurring_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  category_id UUID REFERENCES public.wallet_categories(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  amount_paise BIGINT NOT NULL,
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
  start_date DATE NOT NULL,
  end_date DATE,
  next_due_date DATE NOT NULL,
  reminder_days_before INTEGER NOT NULL DEFAULT 3,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- Add FK from transactions to recurring_transactions
ALTER TABLE public.transactions
  ADD CONSTRAINT fk_txn_recurring
  FOREIGN KEY (recurring_transaction_id)
  REFERENCES public.recurring_transactions(id) ON DELETE SET NULL;

-- -------------------------------------------------------
-- shopping_lists + items (Phase 6)
-- -------------------------------------------------------
CREATE TABLE public.shopping_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.shopping_list_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id UUID NOT NULL REFERENCES public.shopping_lists(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  estimated_paise BIGINT,
  actual_paise BIGINT,
  is_purchased BOOLEAN NOT NULL DEFAULT false,
  purchased_at TIMESTAMPTZ,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- -------------------------------------------------------
-- investments: mutual funds + stocks (Phase 7)
-- -------------------------------------------------------
CREATE TABLE public.investment_holdings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  instrument_type TEXT NOT NULL CHECK (instrument_type IN ('mutual_fund', 'stock')),
  instrument_name TEXT NOT NULL,
  instrument_code TEXT,  -- AMFI code for MF, NSE symbol for stocks
  units_micro BIGINT NOT NULL DEFAULT 0,  -- units × 10000 (3.4567 → 34567)
  avg_buy_price_paise BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.investment_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  holding_id UUID NOT NULL REFERENCES public.investment_holdings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('buy', 'sell', 'dividend', 'switch_in', 'switch_out')),
  units_micro BIGINT NOT NULL,
  price_paise BIGINT NOT NULL,  -- NAV or price per unit in paise
  amount_paise BIGINT NOT NULL,  -- total amount
  transaction_date DATE NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.nav_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_code TEXT NOT NULL,  -- AMFI code
  nav_date DATE NOT NULL,
  nav_paise BIGINT NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(instrument_code, nav_date)
);

CREATE TABLE public.price_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_code TEXT NOT NULL,  -- NSE symbol
  price_date DATE NOT NULL,
  close_paise BIGINT NOT NULL,
  fetched_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(instrument_code, price_date)
);

CREATE TABLE public.sip_schedules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  holding_id UUID NOT NULL REFERENCES public.investment_holdings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  amount_paise BIGINT NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('monthly', 'weekly', 'quarterly')),
  debit_day INTEGER NOT NULL CHECK (debit_day BETWEEN 1 AND 31),
  start_date DATE NOT NULL,
  end_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- -------------------------------------------------------
-- documents: receipts + standalone docs (Phase 8)
-- -------------------------------------------------------
CREATE TABLE public.documents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  category TEXT,  -- manual category like "Warranty", "Receipt", "Manual"
  file_path TEXT NOT NULL,  -- Supabase Storage path
  file_type TEXT NOT NULL,  -- 'image/jpeg', 'application/pdf'
  file_size_bytes INTEGER NOT NULL,
  expiry_date DATE,  -- for warranty tracking
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- -------------------------------------------------------
-- SMS parsing (Phase 9)
-- -------------------------------------------------------
CREATE TABLE public.sms_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  sender_pattern TEXT NOT NULL,  -- regex for SMS sender ID
  body_pattern TEXT NOT NULL,  -- regex for amount extraction
  bank_name TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.sms_merchant_mappings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  merchant_name TEXT NOT NULL,
  category_id UUID REFERENCES public.wallet_categories(id) ON DELETE SET NULL,
  wallet_id UUID REFERENCES public.wallets(id) ON DELETE SET NULL,
  times_used INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, merchant_name)
);

-- -------------------------------------------------------
-- debt instruments: EMIs, loans (Phase 10)
-- -------------------------------------------------------
CREATE TABLE public.debt_instruments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  debt_type TEXT NOT NULL CHECK (debt_type IN ('emi', 'loan_given', 'loan_received')),
  name TEXT NOT NULL,  -- "Car Loan", "Lent to Ravi"
  principal_paise BIGINT NOT NULL,
  remaining_paise BIGINT NOT NULL,
  interest_rate_bps INTEGER,  -- basis points (7.5% = 750)
  emi_paise BIGINT,
  tenure_months INTEGER,
  counterparty_name TEXT,  -- who owes / who is owed
  start_date DATE NOT NULL,
  end_date DATE,
  next_payment_date DATE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  recurring_transaction_id UUID REFERENCES public.recurring_transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_instrument_id UUID NOT NULL REFERENCES public.debt_instruments(id) ON DELETE CASCADE,
  transaction_id UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  amount_paise BIGINT NOT NULL,
  payment_date DATE NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------------
-- financial_goals (Phase 12)
-- -------------------------------------------------------
CREATE TABLE public.financial_goals (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  target_paise BIGINT NOT NULL,
  current_paise BIGINT NOT NULL DEFAULT 0,
  target_date DATE,
  icon TEXT,
  color TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.goal_contributions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id UUID NOT NULL REFERENCES public.financial_goals(id) ON DELETE CASCADE,
  amount_paise BIGINT NOT NULL,
  contributed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -------------------------------------------------------
-- life_organizer (Phase 12)
-- -------------------------------------------------------
CREATE TABLE public.task_lists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_by UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.tasks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id UUID NOT NULL REFERENCES public.task_lists(id) ON DELETE CASCADE,
  assigned_to UUID REFERENCES auth.users(id),
  title TEXT NOT NULL,
  is_completed BOOLEAN NOT NULL DEFAULT false,
  completed_at TIMESTAMPTZ,
  due_date TIMESTAMPTZ,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.calendar_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  event_type TEXT NOT NULL CHECK (event_type IN ('custom', 'sip', 'bill', 'emi', 'warranty', 'birthday', 'anniversary', 'other')),
  event_date DATE NOT NULL,
  is_recurring BOOLEAN NOT NULL DEFAULT false,
  recurrence_rule TEXT,  -- simplified RRULE: 'yearly', 'monthly'
  related_id UUID,  -- FK to source record (SIP, recurring_txn, etc.)
  related_table TEXT,  -- which table the related_id points to
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,  -- "Netflix", "Spotify"
  amount_paise BIGINT NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('monthly', 'yearly', 'quarterly')),
  renewal_date DATE NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  recurring_transaction_id UUID REFERENCES public.recurring_transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

CREATE TABLE public.important_dates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,  -- "Mom's Birthday"
  date_type TEXT NOT NULL CHECK (date_type IN ('birthday', 'anniversary', 'renewal', 'other')),
  event_date DATE NOT NULL,  -- stores the date (year for age calc)
  reminder_days_before INTEGER NOT NULL DEFAULT 7,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);

-- -------------------------------------------------------
-- notification_preferences
-- -------------------------------------------------------
CREATE TABLE public.notification_preferences (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type TEXT NOT NULL,  -- 'budget_80', 'budget_100', 'bill_reminder', etc.
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE(user_id, notification_type)
);

-- -------------------------------------------------------
-- sync_queue: outbound sync tracking (Phase 4)
-- -------------------------------------------------------
CREATE TABLE public.sync_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  table_name TEXT NOT NULL,
  record_id UUID NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  synced_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### Helper Functions & Triggers

```sql
-- =================================================================
-- Migration 003: Helper Functions & Triggers
-- =================================================================

-- -------------------------------------------------------
-- Auto-update server_updated_at on every write
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.set_server_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.server_updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all tables with server_updated_at column
DO $$ 
DECLARE
  tbl RECORD;
BEGIN
  FOR tbl IN
    SELECT table_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name = 'server_updated_at'
  LOOP
    EXECUTE format(
      'CREATE TRIGGER set_server_updated_at BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_server_updated_at()',
      tbl.table_name
    );
  END LOOP;
END $$;

-- -------------------------------------------------------
-- Auto-enable RLS on new tables (deny-all by default)
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION rls_auto_enable()
RETURNS EVENT_TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table', 'partitioned table')
  LOOP
    IF cmd.schema_name IS NOT NULL
      AND cmd.schema_name IN ('public')
      AND cmd.schema_name NOT IN ('pg_catalog', 'information_schema')
      AND cmd.schema_name NOT LIKE 'pg_toast%'
      AND cmd.schema_name NOT LIKE 'pg_temp%'
    THEN
      BEGIN
        EXECUTE format('ALTER TABLE IF EXISTS %s ENABLE ROW LEVEL SECURITY', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
    END IF;
  END LOOP;
END;
$$;

DROP EVENT TRIGGER IF EXISTS ensure_rls;
CREATE EVENT TRIGGER ensure_rls
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
EXECUTE FUNCTION rls_auto_enable();

-- -------------------------------------------------------
-- Helper: Get visible wallet IDs for current user
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION private.visible_wallet_ids()
RETURNS uuid[]
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(array_agg(w.id), ARRAY[]::uuid[])
  FROM public.wallets w
  WHERE w.deleted_at IS NULL
    AND (
      -- User's own private wallet
      w.user_id = (SELECT auth.uid())
      -- Shared wallet in user's household
      OR (
        w.wallet_type = 'shared'
        AND w.household_id IN (
          SELECT hm.household_id
          FROM public.household_members hm
          WHERE hm.user_id = (SELECT auth.uid())
            AND hm.left_at IS NULL
        )
      )
    )
$$;

-- -------------------------------------------------------
-- Helper: Get user's household ID
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION private.user_household_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT hm.household_id
  FROM public.household_members hm
  WHERE hm.user_id = (SELECT auth.uid())
    AND hm.left_at IS NULL
  LIMIT 1
$$;

-- -------------------------------------------------------
-- Trigger: Auto-create profile on auth.users insert
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

**Confidence: HIGH** — Schema follows all locked decisions (integer paise, UUIDs, timestamp discipline, wallet_id on privacy rows). RLS auto-enable trigger verified from Context7 Supabase docs.

---

## 4. Drift Local Schema

### Setup for Cross-Platform (Android + Web)

From Context7 Drift docs, the recommended approach uses `drift_flutter` which handles platform differences automatically:

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  // Phase 1 active
  Profiles, Households, HouseholdMembers, HouseholdInvites,
  Wallets, WalletCategories,
  // Phase 2+
  Transactions, TransactionPresets,
  Budgets, RecurringTransactions,
  ShoppingLists, ShoppingListItems,
  InvestmentHoldings, InvestmentTransactions, NavHistory, PriceHistory, SipSchedules,
  Documents,
  SmsRules, SmsMerchantMappings,
  DebtInstruments, DebtPayments,
  FinancialGoals, GoalContributions,
  TaskLists, Tasks, CalendarEvents, Subscriptions, ImportantDates,
  NotificationPrefs,
  SyncQueue,
], daos: [
  WalletDao, CategoryDao, HouseholdDao,
  // Add more DAOs as phases activate
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e])
      : super(
          e ?? driftDatabase(
            name: 'personal_finance',
            native: DriftNativeOptions(
              shareAcrossIsolates: true,
            ),
            web: DriftWebOptions(
              sqlite3Wasm: Uri.parse('sqlite3.wasm'),
              driftWorker: Uri.parse('drift_worker.js'),
              onResult: (result) {
                if (result.missingFeatures.isNotEmpty) {
                  debugPrint('Drift web: ${result.chosenImplementation} '
                      '(missing: ${result.missingFeatures})');
                }
              },
            ),
          ),
        );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (m) async {
        await m.createAll();
      },
      beforeOpen: (details) async {
        // Enable foreign keys (SQLite requires this per-connection)
        await customStatement('PRAGMA foreign_keys = ON');
        // Validate schema in debug mode
        if (kDebugMode) {
          await validateDatabaseSchema();
        }
      },
    );
  }
}
```

### Example Drift Table Definitions (Phase 1 Active)

```dart
// tables/wallets_table.dart
import 'package:drift/drift.dart';

class Wallets extends Table {
  TextColumn get id => text()();  // UUID string
  TextColumn get householdId => text()();
  TextColumn get userId => text().nullable()();  // NULL for shared
  TextColumn get walletType => text()();  // 'shared' or 'private'
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class WalletCategories extends Table {
  TextColumn get id => text()();
  TextColumn get walletId => text().references(Wallets, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isIncome => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### DAO Pattern

```dart
// daos/wallet_dao.dart
import 'package:drift/drift.dart';
import '../app_database.dart';

part 'wallet_dao.g.dart';

@DriftAccessor(tables: [Wallets, WalletCategories])
class WalletDao extends DatabaseAccessor<AppDatabase> with _$WalletDaoMixin {
  WalletDao(super.db);

  // Watch wallets for a list of wallet IDs (privacy-scoped)
  Stream<List<Wallet>> watchVisibleWallets(List<String> walletIds) {
    return (select(wallets)
      ..where((w) => w.id.isIn(walletIds))
      ..where((w) => w.deletedAt.isNull())
    ).watch();
  }

  Future<void> createWallet(WalletsCompanion wallet) {
    return into(wallets).insert(wallet);
  }

  // Seed default categories for a wallet
  Future<void> seedDefaultCategories(String walletId) async {
    const defaults = [
      'Food', 'Transport', 'Shopping', 'Bills',
      'Health', 'Entertainment', 'Education', 'Miscellaneous',
    ];
    await batch((b) {
      for (var i = 0; i < defaults.length; i++) {
        b.insert(walletCategories, WalletCategoriesCompanion.insert(
          id: Value(const Uuid().v4()),
          walletId: walletId,
          name: defaults[i],
          sortOrder: Value(i),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ));
      }
    });
  }
}
```

### Code Generation

```bash
# One-time build
dart run build_runner build --delete-conflicting-outputs

# Watch mode during development
dart run build_runner watch --delete-conflicting-outputs
```

### Schema Migrations (Future)

Use Drift's `make-migrations` tool for step-by-step migrations:
```bash
# Export current schema
dart run drift_dev schema dump lib/data/database/app_database.dart drift_schemas/

# After schema change, generate migration code
dart run drift_dev schema steps drift_schemas/ lib/data/database/schema_versions.dart
```

**Confidence: HIGH** — All patterns verified via Context7 Drift docs. Cross-platform setup with `drift_flutter` is the current recommended approach.

---

## 5. RLS Privacy Wall

### Strategy

| Table Category | RLS Needed | Policy Type |
|----------------|-----------|-------------|
| `profiles` | Yes | User sees own profile only |
| `households` | No (but restrict via membership) | Via `household_members` join |
| `household_members` | Yes | User sees own household members only |
| `household_invites` | Yes | User sees invites for their household |
| `wallets` | Yes | `visible_wallet_ids()` function |
| `wallet_categories` | Yes | Via wallet visibility |
| `transactions` | Yes | Via wallet visibility |
| `budgets`, `documents`, `investments` | Yes | Via wallet visibility |
| `shopping_lists` | Yes | Via wallet visibility |
| `task_lists`, `tasks` | Yes | Via household membership |
| `nav_history`, `price_history` | No | Public market data |
| `sync_log` | Yes | User's own sync records |

### Core RLS Policies

```sql
-- =================================================================
-- Migration 004: RLS Policies
-- =================================================================

-- Revoke all from anon role (defense-in-depth)
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- ---- profiles ----
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- ---- household_members ----
ALTER TABLE public.household_members ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own household members"
  ON public.household_members FOR SELECT TO authenticated
  USING (
    household_id = (SELECT private.user_household_id())
  );

CREATE POLICY "Users can insert to own household"
  ON public.household_members FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR household_id = (SELECT private.user_household_id())
  );

-- ---- households ----
ALTER TABLE public.households ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see own household"
  ON public.households FOR SELECT TO authenticated
  USING (
    id = (SELECT private.user_household_id())
  );

CREATE POLICY "Users can create household"
  ON public.households FOR INSERT TO authenticated
  WITH CHECK (
    created_by = (SELECT auth.uid())
  );

CREATE POLICY "Users can update own household"
  ON public.households FOR UPDATE TO authenticated
  USING (id = (SELECT private.user_household_id()));

-- ---- household_invites ----
ALTER TABLE public.household_invites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own household invites"
  ON public.household_invites FOR ALL TO authenticated
  USING (
    household_id = (SELECT private.user_household_id())
  )
  WITH CHECK (
    household_id = (SELECT private.user_household_id())
  );

-- Special: Invitee reads invite by token (no auth needed during signup flow)
-- This is handled via a server function, not direct table access

-- ---- wallets ----
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see visible wallets"
  ON public.wallets FOR SELECT TO authenticated
  USING (id = ANY((SELECT private.visible_wallet_ids())));

CREATE POLICY "Users can insert wallets in own household"
  ON public.wallets FOR INSERT TO authenticated
  WITH CHECK (
    household_id = (SELECT private.user_household_id())
  );

CREATE POLICY "Users can update visible wallets"
  ON public.wallets FOR UPDATE TO authenticated
  USING (id = ANY((SELECT private.visible_wallet_ids())));

-- ---- wallet_categories ----
ALTER TABLE public.wallet_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users see categories for visible wallets"
  ON public.wallet_categories FOR SELECT TO authenticated
  USING (wallet_id = ANY((SELECT private.visible_wallet_ids())));

CREATE POLICY "Users manage categories for visible wallets"
  ON public.wallet_categories FOR ALL TO authenticated
  USING (wallet_id = ANY((SELECT private.visible_wallet_ids())))
  WITH CHECK (wallet_id = ANY((SELECT private.visible_wallet_ids())));

-- ---- GENERIC WALLET-SCOPED POLICY ----
-- Apply the same pattern to ALL wallet-scoped tables:
-- transactions, budgets, recurring_transactions, shopping_lists,
-- investment_holdings, documents, debt_instruments, financial_goals,
-- subscriptions, transaction_presets

-- Template (repeat for each table):
/*
ALTER TABLE public.{TABLE} ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users access {TABLE} for visible wallets"
  ON public.{TABLE} FOR ALL TO authenticated
  USING (wallet_id = ANY((SELECT private.visible_wallet_ids())))
  WITH CHECK (wallet_id = ANY((SELECT private.visible_wallet_ids())));
*/

-- Apply to all wallet-scoped tables
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'transactions', 'transaction_presets', 'budgets',
    'recurring_transactions', 'shopping_lists',
    'investment_holdings', 'documents', 'debt_instruments',
    'financial_goals', 'subscriptions', 'sip_schedules'
  ]
  LOOP
    EXECUTE format(
      'CREATE POLICY "Users access %1$s for visible wallets" ON public.%1$I FOR ALL TO authenticated USING (wallet_id = ANY((SELECT private.visible_wallet_ids()))) WITH CHECK (wallet_id = ANY((SELECT private.visible_wallet_ids())))',
      tbl
    );
  END LOOP;
END $$;

-- ---- user-scoped tables (no wallet_id, uses user_id) ----
-- sms_rules, sms_merchant_mappings, notification_preferences

DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'sms_rules', 'sms_merchant_mappings', 'notification_preferences'
  ]
  LOOP
    EXECUTE format(
      'CREATE POLICY "Users access own %1$s" ON public.%1$I FOR ALL TO authenticated USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()))',
      tbl
    );
  END LOOP;
END $$;

-- ---- household-scoped tables ----
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'task_lists', 'calendar_events', 'important_dates'
  ]
  LOOP
    EXECUTE format(
      'CREATE POLICY "Users access %1$s in own household" ON public.%1$I FOR ALL TO authenticated USING (household_id = (SELECT private.user_household_id())) WITH CHECK (household_id = (SELECT private.user_household_id()))',
      tbl
    );
  END LOOP;
END $$;

-- ---- child tables (via parent FK) ----
ALTER TABLE public.shopping_list_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users access items via list"
  ON public.shopping_list_items FOR ALL TO authenticated
  USING (
    list_id IN (
      SELECT id FROM public.shopping_lists
      WHERE wallet_id = ANY((SELECT private.visible_wallet_ids()))
    )
  )
  WITH CHECK (
    list_id IN (
      SELECT id FROM public.shopping_lists
      WHERE wallet_id = ANY((SELECT private.visible_wallet_ids()))
    )
  );

ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users access tasks via list"
  ON public.tasks FOR ALL TO authenticated
  USING (
    list_id IN (
      SELECT id FROM public.task_lists
      WHERE household_id = (SELECT private.user_household_id())
    )
  );

ALTER TABLE public.investment_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users access investment txns via holding"
  ON public.investment_transactions FOR ALL TO authenticated
  USING (
    holding_id IN (
      SELECT id FROM public.investment_holdings
      WHERE wallet_id = ANY((SELECT private.visible_wallet_ids()))
    )
  );

ALTER TABLE public.debt_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users access debt payments via instrument"
  ON public.debt_payments FOR ALL TO authenticated
  USING (
    debt_instrument_id IN (
      SELECT id FROM public.debt_instruments
      WHERE wallet_id = ANY((SELECT private.visible_wallet_ids()))
    )
  );

ALTER TABLE public.goal_contributions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users access goal contributions via goal"
  ON public.goal_contributions FOR ALL TO authenticated
  USING (
    goal_id IN (
      SELECT id FROM public.financial_goals
      WHERE wallet_id = ANY((SELECT private.visible_wallet_ids()))
    )
  );

-- ---- Public data (no RLS) ----
-- nav_history and price_history are public market data
ALTER TABLE public.nav_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Market data is public"
  ON public.nav_history FOR SELECT TO authenticated
  USING (true);

ALTER TABLE public.price_history ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Market data is public"
  ON public.price_history FOR SELECT TO authenticated
  USING (true);

-- ---- sync_log ----
ALTER TABLE public.sync_log ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users see own sync log"
  ON public.sync_log FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
```

### SQL Privacy Wall Assertion Tests

```sql
-- =================================================================
-- supabase/tests/rls_privacy_test.sql
-- Run with: supabase test db
-- =================================================================

BEGIN;
SELECT plan(6);

-- Setup: Create two test users, household, wallets
-- (In real tests, use supabase test helpers to set auth.uid())

-- Test 1: User A cannot see User B's private wallet
SELECT is(
  (SELECT count(*) FROM public.wallets
   WHERE wallet_type = 'private' AND user_id != (SELECT auth.uid())),
  0::bigint,
  'User cannot see other users private wallets'
);

-- Test 2: User A can see shared wallet
SELECT isnt(
  (SELECT count(*) FROM public.wallets
   WHERE wallet_type = 'shared'),
  0::bigint,
  'User can see shared wallet'
);

-- Test 3: User A cannot see User B's private wallet transactions
SELECT is(
  (SELECT count(*) FROM public.transactions t
   JOIN public.wallets w ON t.wallet_id = w.id
   WHERE w.wallet_type = 'private' AND w.user_id != (SELECT auth.uid())),
  0::bigint,
  'User cannot see other users private transactions'
);

-- Test 4: User A cannot see User B's private wallet categories
SELECT is(
  (SELECT count(*) FROM public.wallet_categories wc
   JOIN public.wallets w ON wc.wallet_id = w.id
   WHERE w.wallet_type = 'private' AND w.user_id != (SELECT auth.uid())),
  0::bigint,
  'User cannot see other users private categories'
);

-- Test 5: All tables in public schema have RLS enabled
SELECT is(
  (SELECT count(*)
   FROM pg_tables
   WHERE schemaname = 'public'
     AND tablename NOT IN ('schema_migrations')
     AND tablename NOT IN (
       SELECT tablename FROM pg_tables
       WHERE schemaname = 'public' AND rowsecurity = true
     )),
  0::bigint,
  'All public tables have RLS enabled'
);

-- Test 6: All privacy-sensitive tables have at least one policy
SELECT is(
  (SELECT count(*)
   FROM pg_tables t
   WHERE t.schemaname = 'public'
     AND t.rowsecurity = true
     AND NOT EXISTS (
       SELECT 1 FROM pg_policies p
       WHERE p.schemaname = t.schemaname AND p.tablename = t.tablename
     )),
  0::bigint,
  'All RLS-enabled tables have at least one policy'
);

SELECT * FROM finish();
ROLLBACK;
```

### Performance Indexes

The `(SELECT auth.uid())` pattern (with the SELECT wrapper) is critical — it caches the function result per-statement rather than evaluating per-row. This is the Supabase-recommended optimization from Context7 docs.

Every table with wallet_id should have an index:
```sql
CREATE INDEX idx_{table}_wallet ON public.{table}(wallet_id);
```

**Confidence: HIGH** — RLS patterns verified from Context7 Supabase docs. Auto-RLS trigger is the exact code from Supabase official documentation.

---

## 6. Authentication Flow

### Email/Password Signup

From Context7 Supabase Flutter docs:

```dart
// Sign up
final AuthResponse res = await supabase.auth.signUp(
  email: 'user@example.com',
  password: 'securepassword123',
  data: {'display_name': 'John'},  // stored in raw_user_meta_data
);
final Session? session = res.session;
final User? user = res.user;

// Sign in
final AuthResponse res = await supabase.auth.signInWithPassword(
  email: 'user@example.com',
  password: 'securepassword123',
);

// Sign out
await supabase.auth.signOut();

// Listen to auth state changes
supabase.auth.onAuthStateChange.listen((data) {
  final AuthChangeEvent event = data.event;
  final Session? session = data.session;

  switch (event) {
    case AuthChangeEvent.signedIn:
      // Navigate to dashboard
      break;
    case AuthChangeEvent.signedOut:
      // Navigate to login
      break;
    case AuthChangeEvent.tokenRefreshed:
      // Session refreshed
      break;
    default:
      break;
  }
});
```

### Session Persistence

Supabase Flutter SDK v2 handles session persistence automatically:
- Session stored in `SharedPreferences` (Flutter) / `localStorage` (Web)
- On app launch, `Supabase.initialize()` loads session from storage immediately (no network call)
- JWT auto-refresh happens in background when token is near expiry
- Default JWT expiry: 3600 seconds (1 hour) — configurable in Supabase dashboard

**Decision (Claude's Discretion):** Use default 1-hour JWT expiry. No custom refresh logic needed — Supabase SDK handles it. Only check `isExpired` if making a critical operation after the app was backgrounded for hours.

### Custom Household Invite System

Since the user specified a custom invite system (not Supabase native magic links):

**Flow:**
1. First user signs up → `handle_new_user()` trigger creates profile
2. First user goes through onboarding wizard → creates household + wallets + categories
3. Onboarding step: "Invite your partner" → generates invite
4. API creates `household_invites` row with:
   - `invite_code`: 8-char alphanumeric (for manual entry)
   - `invite_token`: UUID (for magic link URL)
   - `expires_at`: NOW() + 7 days
5. Magic link format: `https://app.example.com/invite/{invite_token}`
6. Second user clicks link → opens app/web → signup screen pre-filled with invite context
7. After signup, accept invite: validate token + create household_member + create private wallet + seed categories

**Invite Acceptance (Supabase RPC function):**

```sql
CREATE OR REPLACE FUNCTION public.accept_invite(p_invite_token UUID)
RETURNS UUID  -- returns household_id
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invite RECORD;
  v_user_id UUID;
  v_household_id UUID;
  v_wallet_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Find valid invite
  SELECT * INTO v_invite
  FROM public.household_invites
  WHERE invite_token = p_invite_token
    AND accepted_at IS NULL
    AND revoked_at IS NULL
    AND expires_at > now();

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  v_household_id := v_invite.household_id;

  -- Check not already a member
  IF EXISTS (
    SELECT 1 FROM public.household_members
    WHERE household_id = v_household_id AND user_id = v_user_id AND left_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Already a member of this household';
  END IF;

  -- Add member
  INSERT INTO public.household_members (household_id, user_id, role)
  VALUES (v_household_id, v_user_id, 'member');

  -- Update profile
  UPDATE public.profiles SET household_id = v_household_id WHERE id = v_user_id;

  -- Mark invite accepted
  UPDATE public.household_invites
  SET accepted_by = v_user_id, accepted_at = now()
  WHERE id = v_invite.id;

  -- Create private wallet for new member
  v_wallet_id := gen_random_uuid();
  INSERT INTO public.wallets (id, household_id, user_id, wallet_type, name)
  VALUES (v_wallet_id, v_household_id, v_user_id, 'private', 'My Wallet');

  -- Seed default categories
  INSERT INTO public.wallet_categories (wallet_id, name, sort_order)
  SELECT v_wallet_id, unnest(ARRAY['Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Entertainment', 'Education', 'Miscellaneous']),
         generate_series(0, 7);

  RETURN v_household_id;
END;
$$;
```

**Confidence: HIGH** — Auth flow verified from Context7. Custom invite system is straightforward PostgreSQL.

---

## 7. Onboarding Wizard Pattern

### Multi-Step Form with Riverpod

The onboarding wizard is a multi-step flow. Use a `StateNotifier` or `Notifier` to track wizard state:

```dart
// Onboarding state
@freezed
class OnboardingState with _$OnboardingState {
  const factory OnboardingState({
    @Default(0) int currentStep,
    @Default('') String householdName,
    @Default(false) bool inviteSent,
    @Default(false) bool isLoading,
    String? error,
  }) = _OnboardingState;
}

// Onboarding notifier
@riverpod
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  OnboardingState build() => const OnboardingState();

  void setHouseholdName(String name) {
    state = state.copyWith(householdName: name);
  }

  Future<void> createHousehold() async {
    state = state.copyWith(isLoading: true);
    try {
      // 1. Create household in Supabase
      final household = await supabase.from('households').insert({
        'name': state.householdName,
        'created_by': supabase.auth.currentUser!.id,
      }).select().single();

      // 2. Add self as owner
      await supabase.from('household_members').insert({
        'household_id': household['id'],
        'user_id': supabase.auth.currentUser!.id,
        'role': 'owner',
      });

      // 3. Create shared wallet
      final sharedWallet = await supabase.from('wallets').insert({
        'household_id': household['id'],
        'wallet_type': 'shared',
        'name': '${state.householdName} Shared',
      }).select().single();

      // 4. Create personal wallet
      final privateWallet = await supabase.from('wallets').insert({
        'household_id': household['id'],
        'user_id': supabase.auth.currentUser!.id,
        'wallet_type': 'private',
        'name': 'My Wallet',
      }).select().single();

      // 5. Seed default categories for both wallets
      for (final walletId in [sharedWallet['id'], privateWallet['id']]) {
        await _seedCategories(walletId);
      }

      // 6. Update profile
      await supabase.from('profiles').update({
        'household_id': household['id'],
      }).eq('id', supabase.auth.currentUser!.id);

      state = state.copyWith(currentStep: 1, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<String> generateInviteLink() async {
    // Generate invite in household_invites table
    final invite = await supabase.from('household_invites').insert({
      'household_id': /* from state */,
      'invited_by': supabase.auth.currentUser!.id,
      'invite_code': _generateCode(),  // 8-char alphanumeric
      'expires_at': DateTime.now().add(Duration(days: 7)).toIso8601String(),
    }).select().single();

    return 'https://app.example.com/invite/${invite['invite_token']}';
  }

  void nextStep() => state = state.copyWith(currentStep: state.currentStep + 1);
  void skipInvite() => nextStep();
}
```

### Wizard UI Pattern

```dart
class OnboardingScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingNotifierProvider);

    return Scaffold(
      body: Stepper(
        currentStep: state.currentStep,
        onStepContinue: () {
          switch (state.currentStep) {
            case 0: ref.read(onboardingNotifierProvider.notifier).createHousehold();
            case 1: ref.read(onboardingNotifierProvider.notifier).nextStep();
            case 2: // Complete onboarding, navigate to dashboard
          }
        },
        steps: [
          Step(title: Text('Name your household'), content: HouseholdNameForm()),
          Step(title: Text('Invite your partner'), content: InvitePartnerStep()),
          Step(title: Text('All set!'), content: OnboardingComplete()),
        ],
      ),
    );
  }
}
```

### GoRouter Auth Guard

```dart
final goRouter = GoRouter(
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final isLoggedIn = session != null && !session.isExpired;
    final isOnAuthPage = state.matchedLocation.startsWith('/auth');

    if (!isLoggedIn && !isOnAuthPage) return '/auth/login';
    if (isLoggedIn && isOnAuthPage) return '/';  // or '/onboarding' if not completed
    return null;
  },
  routes: [
    GoRoute(path: '/auth/login', builder: (_, __) => LoginScreen()),
    GoRoute(path: '/auth/signup', builder: (_, __) => SignupScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => OnboardingScreen()),
    GoRoute(path: '/invite/:token', builder: (_, state) =>
      InviteAcceptScreen(token: state.pathParameters['token']!)),
    GoRoute(path: '/', builder: (_, __) => DashboardScreen()),
  ],
);
```

**Confidence: HIGH** — Standard Flutter patterns. Stepper widget is built-in Flutter Material.

---

## 8. Risks & Open Questions

### Risk 1: Supabase Event Trigger Permissions
The `CREATE EVENT TRIGGER` for auto-RLS requires superuser privileges. On Supabase hosted, the `postgres` role has these permissions but the `authenticated` role does not. This must be created via a migration (not client-side). **Mitigation:** Include in migration files that run via `supabase db push`.

### Risk 2: Deep Link Handling for Invite Magic Links
The magic link `https://app.example.com/invite/{token}` needs deep linking configured:
- **Android:** Intent filter in `AndroidManifest.xml`
- **Web:** Standard URL routing (go_router handles this)
- **Risk:** Deep link configuration varies by platform and is fiddly to debug.
- **Mitigation:** For MVP, support sharing the invite_code (8 chars) for manual entry as fallback to deep links.

### Risk 3: Drift Web Storage Persistence
On web, Drift's best storage (OPFS) requires COOP/COEP headers. Without these, it falls back to IndexedDB or in-memory. Private browsing mode in Firefox uses in-memory only.
- **Mitigation:** Web is secondary platform. Show warning if in-memory/unsafe storage detected. For Phase 1, accept this limitation.

### Risk 4: Full Schema Upfront = Large Initial Migration
Creating ~30 tables in one migration is unusual but intentional per user decision. Risk is minor errors in future-feature tables that aren't caught until that phase.
- **Mitigation:** All tables get RLS automatically via event trigger. SQL tests verify every table has RLS. Future phases can ALTER tables if needed (cheaper than CREATE).

### Open Question 1: Onboarding for Second User
When the second user clicks the invite link and signs up, do they go through a simplified onboarding (no household creation, no wallet naming — just "Welcome to {household_name}!")? **Assumed yes** — second user's onboarding is: accept invite → automatic private wallet creation → land on dashboard.

### Open Question 2: Edge Functions vs Client-Side for Invite Acceptance
The `accept_invite` function could be a PostgreSQL RPC function (called via `supabase.rpc()`) or a Supabase Edge Function. **Recommendation:** Use PostgreSQL RPC function. It runs in a transaction, needs no extra deployment, and is faster. Edge Functions are better reserved for logic that needs external API calls.

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | pgTAP (SQL) for RLS tests + Flutter test for Dart |
| Config file | `supabase/tests/` (pgTAP), `test/` (Flutter) |
| Quick run command | `supabase test db` |
| Full suite command | `supabase test db && flutter test` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| AUTH-01 | Email/password signup creates user + profile | integration | `flutter test test/integration/auth_signup_test.dart` | ❌ Wave 0 |
| AUTH-02 | Session persists across app restart | integration | `flutter test test/integration/auth_session_test.dart` | ❌ Wave 0 |
| AUTH-03 | Logout clears session | unit | `flutter test test/unit/auth_service_test.dart` | ❌ Wave 0 |
| AUTH-04 | Invite creates household_member + wallet | SQL + integration | `supabase test db` (invite acceptance) | ❌ Wave 0 |
| AUTH-05 | TLS enforced + pgcrypto available | SQL | `supabase test db` (extension check) | ❌ Wave 0 |
| WALL-01 | Auto-create 3 wallets on household formation | SQL + unit | `supabase test db` + `flutter test test/unit/wallet_dao_test.dart` | ❌ Wave 0 |
| WALL-02 | Private data invisible via RLS | SQL | `supabase test db` (impersonation tests) | ❌ Wave 0 |
| PLAT-05 | Flutter builds on Android + Web | build | `flutter build apk --debug && flutter build web` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `supabase test db` (RLS tests) + `flutter test` (Dart tests)
- **Per wave merge:** Full suite: `supabase test db && flutter test && flutter build apk --debug && flutter build web`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `supabase/tests/rls_privacy_test.sql` — covers WALL-02
- [ ] `supabase/tests/invite_acceptance_test.sql` — covers AUTH-04
- [ ] `test/unit/wallet_dao_test.dart` — covers WALL-01
- [ ] `test/integration/auth_signup_test.dart` — covers AUTH-01
- [ ] pgTAP extension installed: ensure `CREATE EXTENSION IF NOT EXISTS "pgtap"` in first migration

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Auth/session management | Custom JWT handling | Supabase Auth SDK | Handles token refresh, storage, state changes automatically |
| Database access on web | Custom IndexedDB wrapper | `drift_flutter` + `DriftWebOptions` | Handles OPFS/IndexedDB/in-memory fallback automatically |
| UUID generation | Custom ID scheme | `uuid` package v4 | Cryptographically random, zero collision risk |
| Indian currency formatting | Manual string formatting | `intl` package `NumberFormat.currency(locale: 'en_IN')` | Handles lakhs/crores notation correctly |
| Deep link routing | Platform-specific intent parsing | `go_router` with redirect | Handles web URLs and Android intents uniformly |

---

## Sources

### Primary (HIGH confidence)
- Context7 `/websites/supabase_reference_dart` — Auth API, initialization, signup/signin
- Context7 `/websites/supabase` — RLS policies, event triggers, CLI setup, migration workflow
- Context7 `/simolus3/drift` — Table definitions, DAO pattern, web setup, migrations, code generation
- Supabase official RLS docs — `(SELECT auth.uid())` optimization, auto-enable trigger, security_invoker views

### Secondary (MEDIUM confidence)
- Project research: STACK.md, ARCHITECTURE.md, PITFALLS.md — stack decisions, patterns, known issues

### Tertiary (needs validation)
- Deep link configuration specifics — needs testing per platform

## Metadata

**Confidence breakdown:**
- Flutter project setup: HIGH — standard patterns, Context7 verified
- Supabase configuration: HIGH — CLI workflow well-documented
- Database schema: HIGH — relational schema design is deterministic from requirements
- Drift local mirror: HIGH — Context7 verified patterns
- RLS policies: HIGH — Supabase docs explicit, auto-enable trigger verified
- Auth flow: HIGH — Context7 verified signUp/signIn/signOut
- Onboarding wizard: MEDIUM — standard Flutter patterns but not library-specific

**Research date:** 2026-03-17
**Valid until:** 2026-04-17 (30 days — stable libraries, no alpha/beta APIs)
