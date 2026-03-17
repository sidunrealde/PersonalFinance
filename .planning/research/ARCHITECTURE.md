# Architecture Patterns

**Domain:** Offline-first household financial & life organizer
**Researched:** 2026-03-17
**Confidence:** HIGH — Verified via Drift official docs, Supabase RLS docs, Flutter architectural overview

---

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        FLUTTER APP (Android + Web)                      │
│                                                                         │
│  ┌─────────────┐  ┌──────────────┐  ┌────────────┐  ┌──────────────┐  │
│  │  UI Layer   │  │  State Mgmt  │  │  Services   │  │  Platform    │  │
│  │  (Screens,  │←→│  (Riverpod   │←→│  (Sync,     │  │  Channels    │  │
│  │   Widgets)  │  │   Providers) │  │   Auth,     │  │  (SMS only)  │  │
│  └─────────────┘  └──────┬───────┘  │   Invest)   │  └──────┬───────┘  │
│                          │          └──────┬───────┘         │          │
│                          │                 │                 │          │
│                  ┌───────▼─────────────────▼─────────────────▼───────┐  │
│                  │            Repository Layer                       │  │
│                  │   (Privacy-aware data access abstraction)         │  │
│                  └───────────────────┬───────────────────────────────┘  │
│                                     │                                   │
│            ┌────────────────────────┼────────────────────────┐          │
│            │                        │                        │          │
│   ┌────────▼────────┐    ┌─────────▼─────────┐    ┌────────▼────────┐ │
│   │  Drift DAOs     │    │   Sync Engine      │    │  File Manager   │ │
│   │  (Type-safe     │    │   (Queue + Poll    │    │  (Local cache   │ │
│   │   SQLite ORM)   │    │    + Conflict Res)  │    │   + Supabase    │ │
│   └────────┬────────┘    └─────────┬─────────┘    │   Storage)      │ │
│            │                       │               └────────┬────────┘ │
│   ┌────────▼────────┐              │                        │          │
│   │  Local SQLite   │              │                        │          │
│   │  (Drift DB)     │              │                        │          │
│   │  SINGLE SOURCE  │              │                        │          │
│   │  OF TRUTH       │              │                        │          │
│   └─────────────────┘              │                        │          │
│                                    │                        │          │
└────────────────────────────────────┼────────────────────────┼──────────┘
                                     │                        │
                          ┌──────────▼────────────────────────▼──────────┐
                          │              SUPABASE CLOUD                   │
                          │                                               │
                          │  ┌──────────────┐  ┌────────────────────┐    │
                          │  │  PostgREST   │  │  Supabase Storage  │    │
                          │  │  (Auto REST) │  │  (Documents/Images)│    │
                          │  └──────┬───────┘  └────────────────────┘    │
                          │         │                                     │
                          │  ┌──────▼───────────────────────────────────┐ │
                          │  │  PostgreSQL + RLS (Privacy Wall)         │ │
                          │  │  ┌─────────┐ ┌─────────┐ ┌───────────┐  │ │
                          │  │  │ Shared  │ │ Private │ │ Private   │  │ │
                          │  │  │ Wallet  │ │ Wallet  │ │ Wallet    │  │ │
                          │  │  │ (both)  │ │ (User A)│ │ (User B)  │  │ │
                          │  │  └─────────┘ └─────────┘ └───────────┘  │ │
                          │  └──────────────────────────────────────────┘ │
                          │                                               │
                          │  ┌──────────────┐  ┌────────────────────┐    │
                          │  │ Supabase Auth│  │  Edge Functions    │    │
                          │  │ (JWT+uid)    │  │  (Complex logic)   │    │
                          │  └──────────────┘  └────────────────────┘    │
                          └───────────────────────────────────────────────┘

External APIs (client-side, no backend):
  ┌────────────┐  ┌──────────────────┐
  │ mfapi.in   │  │ NSE/BSE/Yahoo    │
  │ (MF NAVs)  │  │ (Stock prices)   │
  └────────────┘  └──────────────────┘
```

---

## Component Responsibilities

### 1. UI Layer
| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Screens** | Page-level widgets (Dashboard, Ledger, Investments, Shopping, Settings) | State providers via `ref.watch`/`ref.read` |
| **Widgets** | Reusable composable widgets (TransactionCard, BudgetGauge, ChartWidget) | Parent screens via callbacks |
| **Navigation** | `go_router` with auth redirect guards | Supabase Auth state, Riverpod |

### 2. State Management Layer (Riverpod)
| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **Auth Providers** | Expose current user, auth state, login/logout | Supabase Auth, Repository |
| **Wallet Providers** | Expose wallet data filtered by privacy rules | Repository Layer |
| **Transaction Providers** | Reactive transaction lists, filtered/sorted | Repository Layer, Drift streams |
| **Sync Providers** | Expose sync status (idle/syncing/error/offline) | Sync Engine, Connectivity |
| **Investment Providers** | Portfolio data, NAV history, SIP schedules | Repository Layer, External APIs |
| **Shopping Providers** | List data, auto-deduct on purchase | Repository Layer |

### 3. Repository Layer (Privacy Boundary)
| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **TransactionRepository** | CRUD transactions with wallet-scoped access | Drift DAOs, Sync Engine |
| **WalletRepository** | Wallet operations, balance calculations | Drift DAOs, Sync Engine |
| **CategoryRepository** | Per-wallet category management | Drift DAOs, Sync Engine |
| **InvestmentRepository** | Fund/stock CRUD, NAV fetching | Drift DAOs, External APIs, Sync Engine |
| **ShoppingRepository** | List CRUD, purchase→transaction auto-creation | Drift DAOs, TransactionRepository |
| **DocumentRepository** | File metadata + upload/download orchestration | Drift DAOs, File Manager, Sync Engine |
| **GoalRepository** | Financial goal tracking | Drift DAOs, Sync Engine |

**Critical:** The Repository Layer is the privacy enforcement point on the client. Every repository method accepts a `walletId` parameter and validates that the current user has access to that wallet before any data operation. This provides defense-in-depth alongside Supabase RLS.

### 4. Data Layer (Drift / SQLite)
| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **AppDatabase** | Central database class, schema definition, migration logic | All DAOs |
| **TransactionDao** | Type-safe transaction queries with `watch()` streams | AppDatabase |
| **WalletDao** | Wallet queries, balance aggregations | AppDatabase |
| **CategoryDao** | Category queries per wallet | AppDatabase |
| **InvestmentDao** | Investment + NAV history queries | AppDatabase |
| **ShoppingDao** | Shopping list + item queries | AppDatabase |
| **DocumentDao** | Document metadata queries | AppDatabase |
| **GoalDao** | Goal queries with progress calculations | AppDatabase |
| **SyncQueueDao** | Outbound sync queue management | AppDatabase |

### 5. Sync Engine
| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **SyncOrchestrator** | Coordinates push/pull cycles on timer + connectivity change | SyncQueueDao, Supabase REST, All DAOs |
| **SyncQueueProcessor** | Processes outbound queue entries (local → cloud) | SyncQueueDao, Supabase REST |
| **RemotePuller** | Pulls changes since last sync timestamp (cloud → local) | Supabase REST, All DAOs |
| **ConflictResolver** | Last-write-wins based on `updated_at` | SyncQueueProcessor, RemotePuller |
| **ConnectivityMonitor** | Detects online/offline transitions, triggers sync | `connectivity_plus`, SyncOrchestrator |

### 6. Platform Services
| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| **SmsParser** (Android only) | Read SMS inbox, extract transaction data via regex | `telephony` package, TransactionRepository |
| **SmsRuleEngine** | Match parsed SMS to merchants, auto-categorize or flag as draft | SmsParser, CategoryRepository |
| **NotificationService** | Budget alerts, SIP reminders, recurring transaction alerts | `flutter_local_notifications`, Providers |
| **FileManager** | Local file cache + Supabase Storage upload/download | `path_provider`, Supabase Storage SDK |

---

## Privacy Wall: Enforcement at Every Layer

The Privacy Wall is not a single feature — it's a cross-cutting architectural constraint enforced at **four independent layers**. Any layer failing would still be caught by the others (defense-in-depth).

```
┌──────────────────────────────────────────────────────────┐
│ Layer 1: UI LAYER                                         │
│ • Dashboard toggle: "Shared" vs "Personal" view           │
│ • UI never renders data from wallets the user can't see   │
│ • Riverpod providers filter by user's visible wallet IDs  │
├──────────────────────────────────────────────────────────┤
│ Layer 2: REPOSITORY LAYER (client-side enforcement)       │
│ • Every query scoped to visibleWalletIds(currentUserId)   │
│ • visibleWalletIds = [shared_wallet_id, my_private_id]    │
│ • Repository rejects requests for non-visible wallets     │
├──────────────────────────────────────────────────────────┤
│ Layer 3: LOCAL DATABASE (Drift)                           │
│ • All queries include WHERE wallet_id IN (?)              │
│ • Sync only pulls data for visible wallets                │
│ • Private wallet data for other user never enters local DB│
├──────────────────────────────────────────────────────────┤
│ Layer 4: CLOUD DATABASE (Supabase PostgreSQL RLS)         │
│ • RLS policies on EVERY table with wallet_id              │
│ • auth.uid() → user's wallets → allowed wallet_ids        │
│ • Even direct PostgREST requests cannot bypass            │
│ • Database-level guarantee: mathematically impossible to   │
│   read another user's private data                        │
└──────────────────────────────────────────────────────────┘
```

### RLS Policy Pattern (Supabase)

```sql
-- Helper: Get wallet IDs visible to current user
CREATE OR REPLACE FUNCTION private.visible_wallet_ids()
RETURNS uuid[]
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT array_agg(w.id)
  FROM wallets w
  LEFT JOIN households h ON w.household_id = h.id
  LEFT JOIN users u ON u.household_id = h.id
  WHERE
    -- User's own private wallet
    w.user_id = (SELECT auth.uid())
    -- Shared wallet for user's household
    OR (w.owner_type = 'shared' AND u.id = (SELECT auth.uid()))
$$;

-- Applied to transactions table (and similarly to all wallet-scoped tables)
CREATE POLICY "Users see only their visible wallets"
ON transactions FOR SELECT
TO authenticated
USING (
  wallet_id = ANY((SELECT private.visible_wallet_ids()))
);

CREATE POLICY "Users insert only to their visible wallets"
ON transactions FOR INSERT
TO authenticated
WITH CHECK (
  wallet_id = ANY((SELECT private.visible_wallet_ids()))
);

-- Same pattern for UPDATE, DELETE
```

### Client-Side Privacy (Repository Layer)

```dart
// In every repository, wallet access is validated before any operation
class TransactionRepository {
  final TransactionDao _dao;
  final AuthService _auth;

  /// Returns wallet IDs this user can access
  List<String> get _visibleWalletIds => [
    _auth.currentUser.sharedWalletId,
    _auth.currentUser.privateWalletId,
  ];

  Stream<List<Transaction>> watchTransactions({required String walletId}) {
    assert(_visibleWalletIds.contains(walletId));
    return _dao.watchByWallet(walletId);
  }
}
```

---

## Data Flow

### Write Path (Offline-First)

```
User Action (add expense)
       │
       ▼
┌──────────────┐
│ Repository   │──── Validates wallet access (Privacy Layer 2)
│ Layer        │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌─────────────────┐
│ Drift DAO    │────→│ Local SQLite DB  │  ← INSTANT write, works offline
│ (insert)     │     │ (source of truth)│
└──────┬───────┘     └─────────────────┘
       │
       ▼
┌──────────────────┐
│ Sync Queue       │  ← Entry created: {table, record_id, operation, timestamp}
│ (sync_queue tbl) │
└──────┬───────────┘
       │
       ▼ (when online, every 30s)
┌──────────────────┐
│ Sync Queue       │────→ POST/PATCH/DELETE to Supabase REST
│ Processor        │      (RLS enforces Privacy Layer 4)
└──────┬───────────┘
       │ on success
       ▼
┌──────────────────┐
│ Remove from      │  ← Queue entry deleted
│ sync_queue       │
└──────────────────┘
       │ on failure
       ▼
┌──────────────────┐
│ Retry with       │  ← Exponential backoff: 1s, 2s, 4s, 8s... max 5min
│ backoff          │
└──────────────────┘
```

### Read Path (Reactive)

```
UI Widget
  │
  │  ref.watch(transactionsProvider(walletId))
  ▼
Riverpod Provider
  │
  │  repository.watchTransactions(walletId: walletId)
  ▼
Repository (validates wallet access)
  │
  │  _dao.watchByWallet(walletId)
  ▼
Drift DAO
  │
  │  SELECT * FROM transactions WHERE wallet_id = ?
  │  ORDER BY timestamp DESC
  │  → Returns Stream<List<Transaction>>
  ▼
Drift Stream Query
  │ Auto-updates when ANY write to transactions table occurs
  ▼
UI rebuilds automatically
```

### Sync Pull Path (Cloud → Local)

```
Sync Timer fires (every 30s when online)
       │
       ▼
┌──────────────────┐
│ Remote Puller    │
│                  │  1. Read last_sync_timestamp from SharedPreferences
│                  │  2. For each synced table:
│                  │     GET /rest/v1/{table}?updated_at=gt.{timestamp}
│                  │     (RLS automatically filters to visible wallets)
│                  │  3. Upsert results into local Drift DB
│                  │  4. Update last_sync_timestamp
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Drift reactive   │──→ UI auto-updates via stream queries
│ streams trigger  │
└──────────────────┘
```

### Conflict Resolution Flow

```
Local record: { id: "abc", amount: 100, updated_at: T1 }
Cloud record:  { id: "abc", amount: 150, updated_at: T2 }

           T2 > T1?
          ╱        ╲
        YES         NO
         │           │
         ▼           ▼
   Cloud wins    Local wins
   (upsert to    (push local
    local DB)     to cloud)

Both users editing same shared transaction simultaneously:
- Probability: Very low (2 users, different times)
- Outcome: Last writer's version persists
- UX: No error shown — feels like a normal overwrite
- Acceptable because: No financial data is lost, just overwritten
```

---

## Sync Queue Schema (Local Drift Table)

```dart
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tableName => text()();           // e.g., 'transactions'
  TextColumn get recordId => text()();            // UUID of the record
  TextColumn get operation => text()();           // 'INSERT', 'UPDATE', 'DELETE'
  TextColumn get payload => text().nullable()();  // JSON of the full record
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
}
```

### Sync Queue Processing Rules

1. **FIFO order** — process oldest entries first to maintain causal ordering
2. **Deduplication** — if multiple writes to the same `(table, record_id)` are queued, collapse into the latest
3. **Retry ceiling** — after 10 retries, move to `failed_sync` table for manual review
4. **Batch processing** — send up to 20 operations per sync cycle to stay within free-tier limits
5. **DELETE wins** — if INSERT + DELETE queued for same record, cancel both (never synced to cloud)

---

## Recommended Project Structure

```
lib/
├── main.dart                      # App entry point, Supabase init
├── app.dart                       # MaterialApp + GoRouter setup
│
├── core/                          # Shared utilities & constants
│   ├── constants/
│   │   ├── app_constants.dart     # Sync intervals, retry limits
│   │   └── supabase_tables.dart   # Table name constants
│   ├── extensions/                # Dart extension methods
│   ├── errors/                    # Custom exception types
│   ├── utils/
│   │   ├── currency_utils.dart    # ₹ formatting, decimal precision
│   │   └── date_utils.dart        # Date helpers
│   └── theme/
│       └── app_theme.dart         # Material 3 theme definition
│
├── data/                          # Data layer (local + remote)
│   ├── database/
│   │   ├── app_database.dart      # @DriftDatabase, schema, migrations
│   │   ├── app_database.g.dart    # Generated
│   │   ├── tables/                # Drift table definitions
│   │   │   ├── wallets_table.dart
│   │   │   ├── transactions_table.dart
│   │   │   ├── categories_table.dart
│   │   │   ├── investments_table.dart
│   │   │   ├── goals_table.dart
│   │   │   ├── shopping_lists_table.dart
│   │   │   ├── list_items_table.dart
│   │   │   ├── documents_table.dart
│   │   │   └── sync_queue_table.dart
│   │   └── daos/                  # Drift DAOs (data access objects)
│   │       ├── transaction_dao.dart
│   │       ├── wallet_dao.dart
│   │       ├── category_dao.dart
│   │       ├── investment_dao.dart
│   │       ├── goal_dao.dart
│   │       ├── shopping_dao.dart
│   │       ├── document_dao.dart
│   │       └── sync_queue_dao.dart
│   │
│   ├── models/                    # Freezed data classes
│   │   ├── transaction.dart
│   │   ├── wallet.dart
│   │   ├── category.dart
│   │   ├── investment.dart
│   │   ├── goal.dart
│   │   ├── shopping_list.dart
│   │   ├── list_item.dart
│   │   └── document.dart
│   │
│   └── repositories/              # Privacy-enforcing data access
│       ├── transaction_repository.dart
│       ├── wallet_repository.dart
│       ├── category_repository.dart
│       ├── investment_repository.dart
│       ├── goal_repository.dart
│       ├── shopping_repository.dart
│       └── document_repository.dart
│
├── services/                      # Business logic services
│   ├── auth/
│   │   └── auth_service.dart      # Supabase Auth wrapper
│   ├── sync/
│   │   ├── sync_orchestrator.dart # Timer + connectivity-driven sync
│   │   ├── sync_queue_processor.dart
│   │   ├── remote_puller.dart
│   │   └── conflict_resolver.dart
│   ├── sms/                       # Android-only SMS parsing
│   │   ├── sms_reader.dart        # Read inbox via telephony
│   │   ├── sms_parser.dart        # Regex-based transaction extraction
│   │   └── sms_rule_engine.dart   # Auto-categorization rules
│   ├── investment/
│   │   ├── nav_fetcher.dart       # mfapi.in client
│   │   └── stock_fetcher.dart     # NSE/BSE/Yahoo client
│   ├── notification/
│   │   └── notification_service.dart
│   └── file/
│       └── file_manager.dart      # Local cache + Supabase Storage
│
├── providers/                     # Riverpod providers
│   ├── auth_providers.dart
│   ├── wallet_providers.dart
│   ├── transaction_providers.dart
│   ├── category_providers.dart
│   ├── investment_providers.dart
│   ├── shopping_providers.dart
│   ├── goal_providers.dart
│   ├── document_providers.dart
│   ├── sync_providers.dart
│   └── database_providers.dart    # DB instance + DAO providers
│
├── features/                      # Feature-based UI modules
│   ├── auth/
│   │   ├── screens/
│   │   └── widgets/
│   ├── dashboard/
│   │   ├── screens/
│   │   └── widgets/
│   ├── ledger/                    # Transaction list + detail
│   │   ├── screens/
│   │   └── widgets/
│   ├── budget/
│   │   ├── screens/
│   │   └── widgets/
│   ├── investments/
│   │   ├── screens/
│   │   └── widgets/
│   ├── shopping/
│   │   ├── screens/
│   │   └── widgets/
│   ├── goals/
│   │   ├── screens/
│   │   └── widgets/
│   ├── documents/
│   │   ├── screens/
│   │   └── widgets/
│   ├── analytics/
│   │   ├── screens/
│   │   └── widgets/
│   └── settings/
│       ├── screens/
│       └── widgets/
│
└── routing/
    └── app_router.dart            # GoRouter config + auth guards

supabase/                          # Supabase project directory
├── migrations/                    # SQL migrations (schema + RLS)
│   ├── 001_init_schema.sql
│   ├── 002_rls_policies.sql
│   └── 003_helper_functions.sql
├── functions/                     # Edge Functions (if needed)
└── config.toml
```

---

## Architectural Patterns

### Pattern 1: Repository Pattern with Privacy Scoping

**What:** Every data operation goes through a repository that enforces wallet visibility before touching the DAO.

**When:** Always — every read/write to wallet-scoped data.

**Why:** Provides client-side defense-in-depth. Even if RLS has a bug, the repository blocks unauthorized access. Also centralizes the "what wallets can this user see?" logic.

```dart
abstract class WalletScopedRepository<T> {
  final AuthService _auth;

  List<String> get _visibleWalletIds => [
    _auth.currentUser.sharedWalletId,
    _auth.currentUser.privateWalletId,
  ];

  void _assertWalletAccess(String walletId) {
    if (!_visibleWalletIds.contains(walletId)) {
      throw PrivacyViolationException(
        'User ${_auth.currentUser.id} cannot access wallet $walletId',
      );
    }
  }
}

class TransactionRepository extends WalletScopedRepository<Transaction> {
  final TransactionDao _dao;
  final SyncQueueDao _syncQueue;

  Future<void> addTransaction(Transaction txn) async {
    _assertWalletAccess(txn.walletId);
    await _dao.insertTransaction(txn);
    await _syncQueue.enqueue('transactions', txn.id, 'INSERT', txn.toJson());
  }
}
```

### Pattern 2: Sync Queue Pattern (Outbox Pattern)

**What:** Every local write appends to a `sync_queue` table. A background processor drains the queue when online.

**When:** Every mutable operation (INSERT, UPDATE, DELETE).

**Why:** Decouples the write path from network availability. The user never waits for network. The queue guarantees eventual consistency with the cloud.

```dart
class SyncOrchestrator {
  Timer? _syncTimer;
  final SyncQueueProcessor _pushProcessor;
  final RemotePuller _pullProcessor;
  final ConnectivityMonitor _connectivity;

  void start() {
    // Sync on connectivity change
    _connectivity.onStatusChange.listen((status) {
      if (status == ConnectivityStatus.online) {
        _runSyncCycle();
      }
    });

    // Periodic sync when online
    _syncTimer = Timer.periodic(Duration(seconds: 30), (_) {
      if (_connectivity.isOnline) {
        _runSyncCycle();
      }
    });
  }

  Future<void> _runSyncCycle() async {
    await _pushProcessor.processQueue();  // Local → Cloud
    await _pullProcessor.pullChanges();   // Cloud → Local
  }
}
```

### Pattern 3: Reactive DAO Streams (Drift `watch()`)

**What:** DAOs expose `Stream<List<T>>` via Drift's `watch()` method. UI subscribes to these streams via Riverpod, auto-rebuilding when data changes.

**When:** Every read operation that needs to reflect real-time data changes.

**Why:** When a sync pull upserts new cloud data into the local DB, Drift automatically triggers stream updates → Riverpod providers re-emit → UI rebuilds. Zero manual refresh logic.

```dart
// In DAO
Stream<List<TransactionEntry>> watchByWallet(String walletId) {
  return (select(transactions)
    ..where((t) => t.walletId.equals(walletId))
    ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
  ).watch();
}

// In Riverpod provider
final transactionsProvider = StreamProvider.family<List<Transaction>, String>(
  (ref, walletId) {
    final repo = ref.watch(transactionRepositoryProvider);
    return repo.watchTransactions(walletId: walletId);
  },
);

// In UI widget
class TransactionList extends ConsumerWidget {
  final String walletId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txns = ref.watch(transactionsProvider(walletId));
    return txns.when(
      data: (list) => ListView.builder(...),
      loading: () => CircularProgressIndicator(),
      error: (e, s) => ErrorWidget(e),
    );
  }
}
```

### Pattern 4: Client-Side UUID Generation

**What:** All record IDs are UUIDs generated on the client at creation time, not auto-incrementing server-side IDs.

**When:** Every record creation, whether online or offline.

**Why:** Offline-first requires creating records without server connectivity. UUIDs eliminate ID collision risk between two users creating records simultaneously offline. Also makes sync idempotent — same UUID means same record, deduplicated naturally via UPSERT.

```dart
import 'package:uuid/uuid.dart';

final txn = Transaction(
  id: const Uuid().v4(),  // Client-generated, globally unique
  walletId: walletId,
  amount: amount,
  // ...
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

### Pattern 5: Timestamp-Based Change Tracking

**What:** Every synced table has `created_at`, `updated_at`, and `server_updated_at` columns. Local writes set `updated_at`. Cloud upserts set `server_updated_at`.

**When:** Every mutable operation, both local and remote.

**Why:** Enables efficient delta sync — "give me everything changed since last sync" is a simple `WHERE updated_at > ?` query. Separating `updated_at` (client) from `server_updated_at` (cloud) prevents sync loops where a pull triggers a push.

```
Local columns:        | Cloud columns:
- created_at          | - created_at
- updated_at          | - updated_at
- is_synced (bool)    | - server_updated_at (set by DB trigger)
- sync_status (enum)  |
```

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Online-First with Offline Fallback
**What:** Building features assuming network availability, then adding offline caching as an afterthought.
**Why bad:** Leads to "degraded mode" UX where features break offline. Impossible to retrofit correctly.
**Instead:** Local SQLite is the source of truth. Cloud is a sync target. Features never call Supabase directly from the UI — always go through Repository → DAO → local DB.

### Anti-Pattern 2: Syncing Everything
**What:** Syncing all data from cloud to every device.
**Why bad:** Privacy leak. User A's device would contain User B's private wallet data.
**Instead:** Sync engine only pulls data for `visibleWalletIds`. Supabase RLS enforces this server-side, and the client explicitly requests only visible wallets.

### Anti-Pattern 3: Direct Supabase Calls from UI
**What:** Calling `Supabase.instance.client.from('transactions').select()` directly in widgets.
**Why bad:** Bypasses offline-first, bypasses privacy validation, creates tight coupling, breaks when offline.
**Instead:** UI → Provider → Repository → DAO → Local DB. Supabase is only touched by the Sync Engine.

### Anti-Pattern 4: Server-Side Integer IDs
**What:** Using auto-increment `bigint` IDs from PostgreSQL as primary keys.
**Why bad:** Two users creating records offline would need server round-trips for IDs. Conflicts when both create a record before syncing.
**Instead:** Client-generated UUIDs for all records.

### Anti-Pattern 5: Single Monolithic Database Class
**What:** Putting all queries in the `AppDatabase` class.
**Why bad:** Becomes unmaintainable as the schema grows (10+ tables, dozens of queries each).
**Instead:** Use Drift DAOs — one per domain area (`TransactionDao`, `WalletDao`, etc.). Keep `AppDatabase` lean: only schema + migration logic.

---

## Wallet & Transfer Data Flow

```
WALLET TYPES:
┌─────────────────────────────────────────┐
│ Household                               │
│                                         │
│  ┌──────────────┐                       │
│  │ Shared Wallet │ ← Both users see     │
│  │ (wallet_type: │                      │
│  │  'shared')    │                      │
│  └──────┬───────┘                       │
│         │                               │
│    ┌────┴─────┐                         │
│    │          │                         │
│  ┌─▼────┐  ┌─▼────┐                    │
│  │User A│  │User B│                     │
│  │Private│  │Private│ ← Only owner sees │
│  │Wallet │  │Wallet │                   │
│  └───────┘  └───────┘                   │
└─────────────────────────────────────────┘

TRANSFER TYPES (all create paired ledger entries):

1. Shared → Private A:
   Shared Wallet: -₹500 (expense: "Transfer to Personal")
   Private A:     +₹500 (income: "Transfer from Shared")
   → Only User A sees the Private side

2. Private A → Shared:
   Private A:     -₹500 (expense: "Transfer to Shared")
   Shared Wallet: +₹500 (income: "Transfer from Personal")
   → Both users see the Shared side

3. Private A → Private B:
   Private A: -₹500 (expense: "Transfer to [User B]")
   Private B: +₹500 (income: "Transfer from [User A]")
   → Each user only sees their own side

KEY INVARIANT: Transfers always create TWO transactions (one per wallet).
               Each transaction respects its wallet's privacy boundary.
               No net money is created or destroyed.
```

---

## Document Storage Architecture

```
User photographs receipt
       │
       ▼
┌──────────────┐
│ image_picker  │
│ / file_picker │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────┐
│ File Manager                  │
│                               │
│  1. Validate: ≤5MB, image/PDF│
│  2. Generate UUID filename    │
│  3. Save to local cache dir   │
│     (path_provider)           │
│  4. Create Document record    │
│     in Drift (metadata only)  │
│  5. Enqueue file upload to    │
│     sync queue                │
└──────────────┬───────────────┘
               │ (when online)
               ▼
┌──────────────────────────────┐
│ Supabase Storage              │
│                               │
│  Bucket: documents            │
│  Path: {household_id}/        │
│         {wallet_id}/          │
│         {uuid}.{ext}          │
│                               │
│  Bucket policy: RLS-like,     │
│  only visible wallet files    │
│  accessible per user          │
└──────────────────────────────┘

PRIVACY: Document path includes wallet_id.
  - Shared wallet docs: both users can access
  - Private wallet docs: only wallet owner can access
  - Supabase Storage policies enforce this server-side
```

---

## SMS Parsing Architecture (Android Only)

```
App opens on Android
       │
       ▼
┌──────────────────────────────┐
│ SMS Reader                    │
│                               │
│  1. Check platform (skip Web) │
│  2. Read last_sms_timestamp   │
│     from SharedPreferences    │
│  3. Query SMS inbox via       │
│     telephony package:        │
│     all messages since        │
│     last_sms_timestamp        │
│  4. Update last_sms_timestamp │
└──────────────┬───────────────┘
               │ raw SMS list
               ▼
┌──────────────────────────────┐
│ SMS Parser                    │
│                               │
│  For each SMS:                │
│  1. Match against bank regex  │
│     patterns (SBI, HDFC,      │
│     ICICI, Axis, etc.)        │
│  2. Extract: amount, type     │
│     (credit/debit), ref no,   │
│     merchant name, balance    │
│  3. Skip non-financial SMS    │
└──────────────┬───────────────┘
               │ parsed transactions
               ▼
┌──────────────────────────────┐
│ SMS Rule Engine               │
│                               │
│  For each parsed transaction: │
│  1. Check ref_no dedup:       │
│     EXISTS in transactions?   │
│     → Skip (already recorded) │
│  2. Match merchant to rules:  │
│     "SWIGGY" → category:Food  │
│     "AMAZON" → category:Shop  │
│  3. Known merchant?           │
│     → Auto-create transaction │
│     Unknown merchant?         │
│     → Create as DRAFT for     │
│       user categorization     │
│  4. Ask user: which wallet?   │
│     (default: private wallet  │
│      of the device owner)     │
└──────────────────────────────┘
```

---

## Investment Data Flow

```
App opens / Manual refresh
       │
       ▼
┌──────────────────────────────┐
│ NAV Fetcher                   │
│                               │
│  1. Check staleness:          │
│     last_nav_fetch > 24h?     │
│  2. GET mfapi.in/mf/{scheme}  │
│     for each held MF scheme   │
│  3. Parse JSON response       │
│  4. Upsert NAV history into   │
│     local Drift DB            │
│  5. Calculate current values: │
│     value = units × latest_nav│
│  6. Enqueue NAV data to sync  │
└──────────────────────────────┘

Stock Fetcher (similar flow):
  NSE/BSE public endpoints → local DB → sync

Portfolio calculations (all local, reactive):
  - Per-fund: units × latest_nav = current_value
  - Per-fund: current_value - invested_amount = gain/loss
  - Total: SUM of all investments per wallet
  - SIP tracking: next_sip_date, monthly_amount, linked fund

All computed in Drift SQL queries (SUM, GROUP BY)
  → Streamed to UI via watch() → auto-updates
```

---

## Build Order (Dependency Graph)

Phases should be built in this order because each depends on the previous:

```
Phase 1: Foundation
├── Supabase project setup (PostgreSQL schema + RLS policies)
├── Flutter project scaffold + Drift database + tables
├── Auth flow (Supabase Auth → JWT → local session)
└── Household + Wallet creation on signup
    Dependencies: None (foundation)

Phase 2: Core Data Layer
├── Drift DAOs for wallets, transactions, categories
├── Repository layer with privacy scoping
├── Riverpod providers wired to repositories
└── Sync queue table + basic sync engine (push only)
    Dependencies: Phase 1 (database + auth)

Phase 3: Core UI + Ledger
├── Dashboard (shared vs personal toggle)
├── Transaction CRUD screens + quick-add
├── Category management per wallet
└── Basic transaction list with filters
    Dependencies: Phase 2 (data layer + providers)

Phase 4: Sync Engine Complete
├── Full push + pull sync cycles
├── Conflict resolution (LWW)
├── Connectivity monitoring + sync status UI
└── Sync on app open + periodic polling
    Dependencies: Phase 2 (DAOs) + Phase 3 (UI to test with)

Phase 5: Budget & Recurring
├── Category budget definitions + alerts
├── Budget progress tracking (SUM queries in Drift)
├── Recurring transaction engine
└── Notifications for budget thresholds
    Dependencies: Phase 2 (transactions) + Phase 4 (sync)

Phase 6: Shopping Lists
├── Shopping list CRUD + wallet linking
├── List item management with estimated costs
├── Purchase → auto-transaction creation
├── Estimated vs actual comparison
    Dependencies: Phase 2 (transactions, wallets)

Phase 7: Investments
├── Investment CRUD (MF + stocks) per wallet
├── NAV fetcher (mfapi.in) + stock price fetcher
├── Portfolio views + gain/loss calculations
├── SIP tracking + calendar
    Dependencies: Phase 2 (data layer) + Phase 4 (sync)

Phase 8: Document Vault
├── File upload (camera + file picker)
├── Local file caching
├── Supabase Storage upload via sync
├── Document viewer (images + PDFs)
├── Link documents to transactions
    Dependencies: Phase 4 (sync) + Phase 3 (transactions UI)

Phase 9: SMS Parsing (Android only)
├── SMS reader + bank regex patterns
├── Rule engine + merchant auto-categorization
├── Draft transaction workflow for unknowns
├── Ref number deduplication
    Dependencies: Phase 2 (transactions) + Phase 5 (categories)

Phase 10: Analytics & Polish
├── Deep analytics (charts, date ranges, comparisons)
├── Financial goals with progress tracking
├── Settings + data export
├── CI/CD pipeline + deployment
    Dependencies: All previous phases
```

### Build Order Rationale

1. **Foundation first** — Everything depends on the database schema, auth, and wallet structure. Getting RLS right here prevents rework later.
2. **Data layer before UI** — Repositories + DAOs + providers are the backbone. Building them first means UI development is fast (just wire up to providers).
3. **Sync after core data** — Sync adds complexity. Having the data layer working offline-only first lets you validate the core architecture without sync noise.
4. **Investments and Documents are independent** — Can be parallelized if needed. Neither depends on the other.
5. **SMS parsing last** — It's Android-only, complex (bank SMS formats), and creates transactions — which means all transaction infrastructure must be solid first.

---

## Scalability Considerations

This is a 2-user household app, so scalability isn't a primary concern. However, the architecture naturally handles growth:

| Concern | At 2 Users | At 10 Users (hypothetical) | Notes |
|---------|------------|----------------------------|-------|
| Data volume | ~500 transactions/month | ~2,500/month | SQLite handles millions of rows trivially |
| Sync frequency | 30s polling | 30s polling still fine | PostgREST handles thousands of req/s |
| Conflicts | Rare (same wallet, same second) | Moderate | LWW still sufficient at this scale |
| Storage | ~50MB local DB after 5 years | ~250MB | SQLite file size on mobile is a non-issue |
| File storage | ~200MB documents/year | ~1GB/year | Would need to move beyond Supabase free tier |
| RLS overhead | Negligible | Negligible | `security definer` function with index, <1ms |

---

## Prerequisites & Initial Setup (Zero-to-Running)

This section assumes you have **nothing set up** — no accounts, no tools installed, no project created.

### Step 0: Accounts to Create (Free)

| Account | URL | What You Need It For | Key Info to Save |
|---------|-----|---------------------|------------------|
| **GitHub** | github.com | Source control, CI/CD, keep-alive cron | Username, email |
| **Supabase** | supabase.com | Cloud database, auth, file storage | Project URL, anon key, service role key |
| **Vercel** | vercel.com | Host the Flutter Web build (static site) | Connect to GitHub repo |

**Order matters:** Create GitHub first → then Supabase (sign in with GitHub) → then Vercel (sign in with GitHub).

### Step 1: Install Development Tools

```
1. Install Flutter SDK
   - Download from: https://docs.flutter.dev/get-started/install
   - Choose your OS (Windows/Mac/Linux)
   - Add Flutter to your system PATH
   - Run: flutter doctor
   - Fix any issues flutter doctor reports (Android SDK, etc.)

2. Install Android Studio (for Android development)
   - Download from: https://developer.android.com/studio
   - During setup: install Android SDK, Android SDK Platform-Tools
   - Open Android Studio → Tools → SDK Manager → install latest Android API
   - Tools → Device Manager → create an Android Virtual Device (emulator)

3. Install VS Code (if not already installed)
   - Extensions to install:
     • Flutter (by Dart Code)
     • Dart (by Dart Code)
     • SQLite Viewer (optional, to inspect local DB)

4. Install Supabase CLI
   - npm install -g supabase  (requires Node.js)
   - OR: brew install supabase/tap/supabase (Mac)
   - OR: scoop install supabase (Windows)
   - Run: supabase --version (verify installation)

5. Install Git
   - Download from: https://git-scm.com/
   - Configure: git config --global user.name "Your Name"
   - Configure: git config --global user.email "your@email.com"
```

### Step 2: Create the Flutter Project

```bash
# Create project
flutter create --org com.household personal_finance
cd personal_finance

# Verify it runs
flutter run -d chrome   # Should open a demo app in Chrome

# Initialize git
git init
git add .
git commit -m "chore: initial Flutter project scaffold"

# Push to GitHub
# (Create repo on github.com first, then:)
git remote add origin https://github.com/YOUR_USERNAME/personal-finance.git
git branch -M main
git push -u origin main
```

### Step 3: Set Up Supabase Project

```
1. Go to supabase.com → sign in with GitHub
2. Click "New Project"
   - Name: personal-finance
   - Database Password: (generate a strong one, save it securely)
   - Region: pick closest to you (e.g., Mumbai for India)
   - Plan: Free
3. Wait ~2 minutes for project to provision
4. Save these values (Settings → API):
   - Project URL:  https://xxxxx.supabase.co
   - anon/public key: eyJhbGci...
   - service_role key: eyJhbGci... (NEVER expose this in client code)
```

### Step 4: Install Flutter Dependencies

```bash
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

# SMS (Android only — will be unused on Web, that's fine)
flutter pub add telephony

# Dev dependencies
flutter pub add --dev drift_dev build_runner freezed json_serializable
flutter pub add --dev mockito flutter_lints

# Verify clean build
flutter pub get
```

### Step 5: Initialize Supabase in Flutter

Create `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',       // Replace with your Project URL
    anonKey: 'YOUR_SUPABASE_ANON_KEY', // Replace with your anon key
  );

  runApp(const MyApp());
}
```

**Security note:** In production, use `--dart-define` to pass these values at build time instead of hardcoding:

```bash
flutter run --dart-define=SUPABASE_URL=https://xxx.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=eyJ...
```

Then access via `const String.fromEnvironment('SUPABASE_URL')` in code.

### Step 6: Create Database Schema on Supabase

In the Supabase Dashboard → SQL Editor, run the initial migration (this will be the first file in `supabase/migrations/`):

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Households
CREATE TABLE households (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Users (extends Supabase auth.users)
CREATE TABLE users (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  household_id UUID REFERENCES households(id),
  name TEXT NOT NULL,
  private_wallet_id UUID,  -- Set after wallet creation
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Wallets
CREATE TABLE wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_type TEXT NOT NULL CHECK (owner_type IN ('shared', 'private')),
  household_id UUID REFERENCES households(id),
  user_id UUID REFERENCES users(id),  -- NULL for shared wallets
  name TEXT NOT NULL,
  balance DECIMAL(15,2) DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Categories
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_id UUID REFERENCES wallets(id),
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'investment')),
  icon TEXT,
  budget_amount DECIMAL(15,2),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Transactions
CREATE TABLE transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_id UUID NOT NULL REFERENCES wallets(id),
  category_id UUID REFERENCES categories(id),
  amount DECIMAL(15,2) NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
  notes TEXT,
  reference_number TEXT,  -- SMS dedup key
  is_draft BOOLEAN DEFAULT false,
  is_recurring BOOLEAN DEFAULT false,
  recurring_rule JSONB,
  timestamp TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

-- Helper function: Get visible wallet IDs for current user
CREATE OR REPLACE FUNCTION private.visible_wallet_ids()
RETURNS uuid[]
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT array_agg(w.id)
  FROM wallets w
  WHERE
    w.user_id = (SELECT auth.uid())
    OR (
      w.owner_type = 'shared'
      AND w.household_id IN (
        SELECT u.household_id FROM users u WHERE u.id = (SELECT auth.uid())
      )
    )
$$;

-- RLS policies for transactions (example — same pattern for all wallet-scoped tables)
CREATE POLICY "Users see own visible wallets' transactions"
  ON transactions FOR SELECT TO authenticated
  USING (wallet_id = ANY((SELECT private.visible_wallet_ids())));

CREATE POLICY "Users insert to own visible wallets"
  ON transactions FOR INSERT TO authenticated
  WITH CHECK (wallet_id = ANY((SELECT private.visible_wallet_ids())));

CREATE POLICY "Users update own visible wallets' transactions"
  ON transactions FOR UPDATE TO authenticated
  USING (wallet_id = ANY((SELECT private.visible_wallet_ids())))
  WITH CHECK (wallet_id = ANY((SELECT private.visible_wallet_ids())));

CREATE POLICY "Users delete own visible wallets' transactions"
  ON transactions FOR DELETE TO authenticated
  USING (wallet_id = ANY((SELECT private.visible_wallet_ids())));

-- Index for RLS performance
CREATE INDEX idx_wallets_user_id ON wallets(user_id);
CREATE INDEX idx_wallets_household_id ON wallets(household_id);
CREATE INDEX idx_transactions_wallet_id ON transactions(wallet_id);
CREATE INDEX idx_categories_wallet_id ON categories(wallet_id);

-- Auto-update updated_at on every UPDATE
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at BEFORE UPDATE ON transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER set_updated_at BEFORE UPDATE ON categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

### Step 7: Set Up Keep-Alive Cron

Create `.github/workflows/supabase-keepalive.yml` in your GitHub repo:

```yaml
name: Supabase Keep-Alive
on:
  schedule:
    - cron: '0 6 */5 * *'  # Every 5 days at 6 AM UTC
  workflow_dispatch:  # Allow manual trigger for testing
jobs:
  ping:
    runs-on: ubuntu-latest
    steps:
      - name: Ping Supabase
        run: |
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
            "${{ secrets.SUPABASE_URL }}/rest/v1/?apikey=${{ secrets.SUPABASE_ANON_KEY }}")
          echo "Supabase responded with: $STATUS"
          if [ "$STATUS" -ne 200 ]; then
            echo "Warning: Unexpected status code"
            exit 1
          fi
```

Then in GitHub → your repo → Settings → Secrets → Actions:
- Add `SUPABASE_URL` = your project URL
- Add `SUPABASE_ANON_KEY` = your anon key

### Step 8: Verify Everything Works

```bash
# 1. Flutter builds
flutter analyze    # Should report no errors
flutter test       # Should pass (default tests)

# 2. App runs on Chrome
flutter run -d chrome

# 3. App runs on Android emulator
flutter run -d emulator-5554  # (or whichever emulator is running)

# 4. Supabase connection works
# (After implementing the main.dart with Supabase init,
#  add a test query to verify connection)
```

---

## Sources

- Drift documentation — DAOs, isolates, stream queries, migrations: https://drift.simonbinder.eu/ — **HIGH confidence**
- Drift isolates documentation: https://drift.simonbinder.eu/docs/advanced-features/isolates/ — **HIGH confidence**
- Drift DAOs documentation: https://drift.simonbinder.eu/docs/advanced-features/daos/ — **HIGH confidence**
- Supabase RLS documentation: https://supabase.com/docs/guides/database/postgres/row-level-security — **HIGH confidence**
- Supabase RLS performance recommendations: https://supabase.com/docs/guides/database/postgres/row-level-security#rls-performance-recommendations — **HIGH confidence**
- Supabase Flutter quickstart: https://supabase.com/docs/guides/getting-started/quickstarts/flutter — **HIGH confidence**
- Supabase Storage bucket policies: https://supabase.com/docs/guides/storage — **HIGH confidence**
- Flutter architectural overview: https://docs.flutter.dev/resources/architectural-overview — **HIGH confidence**
- Offline-first sync patterns (Outbox Pattern): Industry-standard pattern validated across multiple authoritative sources — **HIGH confidence**
- Client-side UUID generation for offline-first: Standard practice for distributed systems — **HIGH confidence**
