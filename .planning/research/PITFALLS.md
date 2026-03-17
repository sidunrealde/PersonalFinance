# Domain Pitfalls

**Domain:** Offline-first household financial & life organizer (Flutter + Drift + Supabase)
**Researched:** 2026-03-17
**Priority focus:** Offline-first sync (per user request)

---

## Critical Pitfalls

Mistakes that cause data loss, rewrites, or security breaches. Each can silently corrupt a production app.

---

### Pitfall 1: Sync Loop — Pull Triggers Push Triggers Pull Forever

**What goes wrong:** Cloud-to-local sync upserts a record and updates `updated_at` in the local Drift DB. The sync queue detects this change and enqueues it as a new outbound write. On next sync, this pushes back to Supabase, which updates `server_updated_at`, and the next pull cycle picks it up again. Infinite loop — each sync cycle doubles the traffic.

**Why it happens:** Using a single `updated_at` column for both local modifications and sync-received updates. The sync engine can't distinguish "user changed this" from "sync wrote this."

**Consequences:** Exponential API calls → blow through Supabase free-tier egress (5GB) in hours. Battery drain on Android. App feels sluggish with constant sync indicator.

**Warning signs:**
- Sync status indicator never settles to "idle"
- `sync_queue` table never empties
- Supabase dashboard shows unexpectedly high API call volume
- Same records appearing repeatedly in sync queue logs

**Prevention:**
1. Use **separate timestamp columns**: `updated_at` (set ONLY on local user writes) and `synced_at` (set ONLY when pulling from cloud). Never let the sync pull path touch `updated_at`.
2. Use `is_synced` boolean flag: set to `false` on local writes, set to `true` after successful push. Only enqueue records where `is_synced = false`.
3. The sync pull path must write directly to the DAO using a dedicated `upsertFromRemote()` method that sets `synced_at` without touching `updated_at` or the sync queue.

**Phase:** Sync Engine (Phase 4 per ARCHITECTURE.md build order). Must be designed correctly from day one — retrofitting this is a full rewrite of the sync layer.

**Confidence:** HIGH — This is the #1 cause of offline-first sync bugs. Documented extensively in CRDTs literature and offline-first community.

---

### Pitfall 2: Floating-Point Money — `double` for Financial Amounts

**What goes wrong:** Dart `double` is IEEE 754 64-bit floating point. `0.1 + 0.2 == 0.30000000000000004`. After thousands of transactions, sums drift visibly. A budget of ₹10,000 might show ₹9,999.97 or ₹10,000.03. Users lose trust immediately.

**Why it happens:** Dart's only numeric type with decimals is `double`. SQLite's `REAL` type is also IEEE 754 float. It's the path of least resistance to use `double` throughout.

**Consequences:**
- Budget calculations silently wrong by paisa amounts — visible in analytics
- Transfer pair invariant breaks: ₹500 out ≠ ₹500 in after float operations
- Investment portfolio gain/loss calculations accumulate error across months
- Reconciliation between SMS-captured amount and stored amount fails

**Warning signs:**
- Budget remaining shows odd fractions (₹499.999999)
- SUM of transactions ≠ manually calculated total
- Transfer pairs don't net to zero
- Tests that compare amounts fail intermittently

**Prevention:**
1. **Store all amounts as integers in paise (1/100 ₹).** `₹500.00` → `50000` (int). All arithmetic is integer. Display-only conversion to ₹ at the UI layer using `intl` package.
2. In Drift: use `IntColumn` for all amount columns. In Supabase: use `bigint` (not `numeric` or `float`).
3. For mutual fund units (3-4 decimal places): store as integer with fixed multiplier. `3.4567 units` → `34567` (÷10000). Document the multiplier in a constant.
4. For NAV values: store as integer in paise. `₹45.6789 NAV` → `456789` (÷10000).
5. Create a `Money` value object in Dart that encapsulates the integer representation and provides display formatting, preventing accidental `double` use.

**Phase:** Foundation/Schema Design (Phase 1). Must be in the schema from the start — migrating from `double` to `int` on a populated database is painful and lossy.

**Confidence:** HIGH — This is a universally documented pitfall in financial software. The `decimal` Dart package exists but adds complexity; integer paise is the standard pattern for Indian currency apps.

---

### Pitfall 3: RLS Policy Gaps — Private Wallet Data Leaks

**What goes wrong:** A new table is added (e.g., `document_metadata`, `sms_rules`, `notification_prefs`) without corresponding RLS policies. By default with RLS enabled but no policies, Supabase returns zero rows — but if RLS is accidentally not enabled on the new table, ALL data is exposed via PostgREST to any authenticated user.

**Why it happens:** RLS is table-by-table. Easy to forget when adding tables during iterative development. Also: PostgreSQL views bypass RLS by default (they run as `security definer` / the creating role, not the invoking user).

**Consequences:** User A can see User B's private wallet transactions, documents, investment holdings. Complete privacy wall failure. Unrecoverable trust breach.

**Warning signs:**
- New table accessible without filters returning more data than expected
- Dashboard showing data that shouldn't be visible
- No RLS test for the new table in CI

**Prevention:**
1. **Auto-enable RLS trigger** (from Supabase docs): Create an event trigger that auto-enables RLS on every new table in the `public` schema:
   ```sql
   CREATE EVENT TRIGGER ensure_rls ON ddl_command_end
   WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
   EXECUTE FUNCTION rls_auto_enable();
   ```
2. **CI gate**: Write pgTAP tests that assert every table in `public` schema has RLS enabled AND has at least one policy. Fail the build if any table lacks this.
3. **Template policy**: Create a reusable helper `private.visible_wallet_ids()` (as in ARCHITECTURE.md). Every wallet-scoped table uses the same function.
4. **Views**: Use `security_invoker = true` (Postgres 15+, which Supabase supports) on all views to inherit underlying table RLS.
5. **Wrap `auth.uid()` in `(SELECT ...)`** in all policies — this caches the result per-statement instead of evaluating per-row, and is the Supabase-recommended performance pattern.

**Phase:** Foundation (Phase 1) for the trigger and helper function. Every subsequent phase that adds tables MUST add RLS tests.

**Confidence:** HIGH — Verified via Supabase official RLS documentation. The `auth.uid()` returns `NULL` for unauthenticated users gotcha is explicitly documented.

---

### Pitfall 4: Sync Queue Foreign Key Ordering — Child Before Parent

**What goes wrong:** User creates a new category, then immediately creates a transaction using that category. Sync queue has: `[INSERT category, INSERT transaction]`. If the sync processor batches these and the category insert fails (network glitch) but the transaction insert proceeds, Supabase rejects the transaction with a foreign key violation. Now the queue is stuck — retrying the transaction always fails until the category syncs first.

**Why it happens:** FIFO queue processing doesn't respect table dependency order. Batch processing may reorder operations for efficiency. Partial batch failures leave the queue in an inconsistent state.

**Consequences:**
- Sync queue permanently stuck on a failed record
- All subsequent operations for that table pile up behind the blocker
- User sees "sync error" indefinitely
- Data silently diverges between local and cloud

**Warning signs:**
- Sync retry counter reaching maximum (10 retries)
- `failed_sync` table accumulating entries
- Specific transactions never appearing in the cloud/other device
- Supabase logs showing FK violation errors

**Prevention:**
1. **Dependency-aware batch ordering**: When building a sync batch, sort by table dependency order: `households` → `wallets` → `categories` → `transactions` → `investments` → `documents`. Parent tables always sync before children.
2. **Transactional batches**: Group related records (a category + its transactions) into a single Supabase RPC call wrapped in a server-side transaction. If any part fails, the whole batch retries together.
3. **On FK error, requeue to end**: If a sync entry fails with a FK violation (HTTP 409 from PostgREST), move it to the end of the queue rather than retrying immediately. The parent record will sync first.
4. **Never skip**: Don't skip failed entries to process later ones in the same table — this can violate causal ordering.

**Phase:** Sync Engine (Phase 4). Design the queue processor with dependency awareness from the start.

**Confidence:** HIGH — Classic distributed systems pitfall. Every custom sync implementation hits this.

---

### Pitfall 5: Clock Skew Breaks Last-Write-Wins

**What goes wrong:** User A's phone clock is 5 minutes ahead. User B edits a shared transaction at 10:00:00 real time. User A edits the same transaction at 10:00:01 real time but their phone says 10:05:01. User A's edit has a later `updated_at` and wins — even though User B's edit was chronologically 4+ minutes after User A's.

**Why it happens:** LWW relies on timestamps being comparable across devices. Phones can have wrong clocks, be in wrong timezones, or have NTP drift. India has a single timezone (IST) which helps, but phone clocks can still be minutes off.

**Consequences:**
- The "wrong" edit wins silently — no conflict UI, no warning
- User B's carefully entered correction is overwritten
- Both users see the "loser's" data briefly before sync overwrites it

**Warning signs:**
- Users reporting "I just changed this but it reverted"
- Transactions appearing to have future timestamps
- Sync seemingly working but data inconsistent between devices

**Prevention:**
1. **Use `server_updated_at` for conflict resolution, not client `updated_at`**: When both records reach Supabase, use a DB trigger that sets `server_updated_at = NOW()` on every INSERT/UPDATE. The server clock is authoritative.
   ```sql
   CREATE OR REPLACE FUNCTION set_server_timestamp()
   RETURNS TRIGGER AS $$
   BEGIN
     NEW.server_updated_at = NOW();
     RETURN NEW;
   END;
   $$ LANGUAGE plpgsql;
   ```
2. **For the pull side**: Use `server_updated_at > last_sync_timestamp` for delta queries. The server assigns the canonical ordering.
3. **For true LWW**: The "last write" should be "last write to reach the server" — not "last client timestamp." This is simpler and immune to clock skew.
4. **Validate client clocks**: On sync, compare server time with device time. If drift > 60 seconds, log a warning. Optionally show a "your device clock may be wrong" banner.

**Phase:** Sync Engine (Phase 4). The server-side trigger should be in Phase 1 (schema setup).

**Confidence:** HIGH — Well-documented distributed systems problem. For 2 users in the same household, conflicts are extremely rare, but when they happen, wrong resolution is worse than no resolution.

---

### Pitfall 6: Drift Web — Data Loss in Private Browsing and Multi-Tab Races

**What goes wrong:** On web, Drift uses different storage backends depending on browser capabilities:
- **Firefox private browsing**: Falls back to in-memory database. All data lost on tab close.
- **Chrome on Android (web)**: No shared workers → `unsafeIndexedDb` mode. Multiple tabs can corrupt the database by writing simultaneously.
- **Missing COOP/COEP headers**: Falls back from OPFS (fast, persistent) to IndexedDB (slower) or in-memory.
- **WAL mode**: Not supported on web at all. Databases using WAL can't be imported.

**Why it happens:** Web browsers have inconsistent support for the FileSystem Access API and SharedArrayBuffer. Drift picks the best available storage but can't guarantee persistence.

**Consequences:**
- User opens app in Firefox private window → logs transactions → closes tab → all data gone
- Two Chrome tabs fighting over IndexedDB → corrupted database → sync queue entries lost
- Data appears to save but is actually in-memory only

**Warning signs:**
- `WasmDatabaseResult.chosenImplementation` returning `unsafeIndexedDb` or `inMemory`
- `missingFeatures` list non-empty in production
- Users on web reporting lost transactions after browser restart

**Prevention:**
1. **Check and warn**: On web startup, check `result.chosenImplementation`. If it's `inMemory` or `unsafeIndexedDb`, show a prominent warning: "Your browser doesn't fully support offline storage. Data may be lost. For best experience, use the Android app or Chrome with standard tabs."
2. **Serve COOP/COEP headers in production**: Configure Vercel to serve `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. This enables the fastest OPFS storage.
3. **But COOP/COEP may break auth popups**: Supabase Auth redirect flow uses popups. Test that `supabase_flutter` email/password auth works with these headers (it should, since email/password doesn't use popups, but OAuth providers would break).
4. **Web is secondary**: The project spec says Android + Web. For web, the offline-first promise is weaker by nature. Accept this and make the web version degrade gracefully — always attempt to sync immediately on web, treat local DB as cache rather than source of truth.

**Phase:** Foundation (Phase 1) for header configuration. Sync Engine (Phase 4) for storage implementation detection and warnings.

**Confidence:** HIGH — Verified via Drift web platform documentation (drift.simonbinder.eu/platforms/web/). Browser support matrix confirmed.

---

### Pitfall 7: Transfer Atomicity — Half-Transfers on Sync Failure

**What goes wrong:** A wallet transfer creates TWO transactions (e.g., Shared -₹500, Private +₹500). Both are written to local Drift DB atomically (using SQLite transaction). But the sync queue processes them as separate entries. If the first syncs successfully but the second fails (network drops mid-batch), the cloud has only half the transfer. The other user sees ₹500 disappear from shared wallet without appearing anywhere.

**Why it happens:** The sync queue treats each record independently. It doesn't understand that certain records form logical groups that must sync together.

**Consequences:**
- Money appears to vanish or appear from nowhere in the other user's view
- Shared wallet balance is wrong until the second leg syncs
- If the second leg retries fail enough times, it moves to `failed_sync` — permanent inconsistency

**Warning signs:**
- Shared wallet balance doesn't match sum of transactions (one leg missing)
- Transfer pair IDs (`transfer_ref`) present on one side but not the other
- Users reporting "where did ₹X go?"

**Prevention:**
1. **Link transfer pairs**: Both transactions share a `transfer_ref` UUID. The sync queue groups entries with the same `transfer_ref` into one batch.
2. **Supabase RPC for atomic transfers**: Instead of two separate INSERT calls, use a Supabase Edge Function or RPC function that inserts both legs in a single database transaction:
   ```sql
   CREATE FUNCTION process_transfer(leg_a jsonb, leg_b jsonb)
   RETURNS void AS $$
   BEGIN
     INSERT INTO transactions SELECT * FROM jsonb_populate_record(null::transactions, leg_a);
     INSERT INTO transactions SELECT * FROM jsonb_populate_record(null::transactions, leg_b);
   END;
   $$ LANGUAGE plpgsql;
   ```
3. **Compensation on failure**: If one leg syncs but the partner doesn't, the next sync cycle must detect the orphan and re-push the missing leg with highest priority.

**Phase:** Core Data Layer (Phase 2) for the transfer_ref design. Sync Engine (Phase 4) for grouped sync.

**Confidence:** HIGH — This is a specific instance of the "distributed transaction" problem applied to the sync queue.

---

## Moderate Pitfalls

Issues that cause significant debugging time, poor UX, or subtle data quality problems.

---

### Pitfall 8: Schema Version Mismatch — Drift vs Supabase

**What goes wrong:** The local Drift schema (SQLite) and the cloud Supabase schema (PostgreSQL) are defined independently and can diverge. A new column added to Supabase but not to the Dart Drift schema is silently ignored during sync pulls. A column added to Drift but not to Supabase causes sync pushes to fail with unknown column errors.

**Prevention:**
1. **Single source of truth**: Define your schema changes as paired migrations — each Drift `schemaVersion` bump has a corresponding Supabase SQL migration file. Never change one without the other.
2. **Use Drift's `make-migrations` command**: Generates migration code and tests automatically. Test every migration step-by-step.
3. **Version negotiation**: Include a `client_schema_version` in sync requests. If the server sees an old client version, return a "please update" response instead of undefined behavior.
4. **Validate at startup in debug mode**: Use Drift's `validateDatabaseSchema()` in `beforeOpen` callback to catch local schema issues early.

**Phase:** Every phase that modifies the database schema.

---

### Pitfall 9: Indian Bank SMS Format Diversity — Regex Fragility

**What goes wrong:** Indian banks have no standard SMS format. Each bank (SBI, HDFC, ICICI, Axis, Kotak, etc.) uses unique templates that change without notice. UPI transaction messages (e.g., from Google Pay, PhonePe) have a different format from direct bank debit/credit alerts. A regex that works for HDFC fails silently for ICICI, parsing zero transactions.

**Specific format challenges:**
- Amount formatting: `Rs.500.00`, `Rs 500`, `INR 500.00`, `Rs.5,00,000.00` (lakhs notation)
- Reference numbers: 12 digits, 16 digits, alphanumeric — no standard
- Merchant names: truncated, ALL CAPS, sometimes in Hindi
- Sender IDs: `JD-SBIBNK`, `AD-HDFCBK`, `JM-ICICIB` — not standardized
- Credit vs Debit: `credited`, `debited`, `received`, `spent`, `paid`, `transferred`
- Balance in some messages, absent in others
- UPI messages: often just `Rs.X paid to MERCHANT via UPI` with no ref number

**Prevention:**
1. **Bank-specific parser registry**: Don't write one mega-regex. Create individual parser classes per known bank/format. Each returns a structured result or `null` (unrecognized).
2. **Fallback generic parser**: For unknown formats, attempt to extract just the amount and credit/debit direction. Create as DRAFT transaction.
3. **Test corpus**: Build a corpus of 100+ real SMS samples (anonymized) across major banks. Use as test fixtures. Update whenever a bank changes format.
4. **Graceful degradation**: A parsing failure should NEVER throw — it should log and skip. The user's app should not crash because of one weird SMS.
5. **User correction feedback loop**: When users recategorize a DRAFT or fix a parsed amount, store the correction to improve future parsing (basic learning).

**Phase:** SMS Parsing (Phase 9). Build the parser registry as extensible from day one.

**Confidence:** HIGH — Every Indian fintech app (CRED, Jupiter, Fi) has teams maintaining bank SMS parsers. It's a known ongoing maintenance burden.

---

### Pitfall 10: Supabase Free-Tier Pausing — Silent Sync Death

**What goes wrong:** Supabase pauses free projects after 1 week of inactivity. "Inactivity" means zero API calls. If both users don't open the app for 8 days (vacation, phone switch, busy week), the Supabase project pauses. On next app open, all Supabase API calls return errors. The app works locally (offline-first saves it), but sync silently fails. The user may not notice for days.

**Prevention:**
1. **GitHub Actions keep-alive cron** (already in STACK.md): Ping Supabase every 5 days. Zero cost, dead simple.
2. **Handle pause gracefully in-app**: When Supabase returns HTTP 503 or connection refused, don't just log it. Show a clear message: "Cloud sync unavailable — your data is safe locally. Sync will resume automatically." Don't spam retries.
3. **Exponential backoff with ceiling**: If Supabase is unreachable, back off from 30s → 1min → 5min → 30min → 1hr max. Don't hammer the endpoint.
4. **500MB database limit awareness**: With NAV history for 50+ mutual fund schemes × 365 days × 5 years, plus transaction history, 500MB fills faster than expected. Monitor and alert.

**Phase:** DevOps/CI setup (Phase 10 or early infrastructure phase). In-app handling in Sync Engine (Phase 4).

**Confidence:** HIGH — Supabase pricing page explicitly states: "Free projects are paused after 1 week of inactivity. Limit of 2 active free projects."

---

### Pitfall 11: Derived vs Stored Balance — Stale Wallet Balance

**What goes wrong:** Storing `balance` as a column on the `wallets` table and incrementing/decrementing it on each transaction. If a transaction syncs but the balance update doesn't (or vice versa), the stored balance diverges from the actual sum of transactions. Over time, this gap grows silently.

**Prevention:**
1. **Never store balance**: Calculate it as `SELECT SUM(CASE WHEN type='income' THEN amount ELSE -amount END) FROM transactions WHERE wallet_id = ?`. Use Drift's `watch()` to make this reactive.
2. **For performance**: Use Drift's computed queries or create a VIEW. On Supabase, create a `wallet_balances` view with `security_invoker = true`.
3. **If caching is needed**: Use a separate `balance_cache` column that's clearly marked as a cache. Recalculate on every app open and after every sync cycle. Never trust the cached value for display — always derive.

**Phase:** Core Data Layer (Phase 2). This must be the pattern from day one.

**Confidence:** HIGH — Classic financial software antipattern. Every accounting system guideline says "derived, never stored."

---

### Pitfall 12: `auth.uid()` NULL in RLS — Unauthenticated Request Silently Passes

**What goes wrong:** An RLS policy like `USING (auth.uid() = user_id)` evaluates to `NULL = user_id` when the user is unauthenticated. In SQL, `NULL = anything` is `false` (actually `NULL`, but treated as false for RLS). This seems safe — the row is excluded. BUT: if the policy uses `auth.uid() IS NOT NULL OR some_other_condition`, the `some_other_condition` could leak rows. More dangerously, if you write `USING (some_function(auth.uid()))` and the function handles NULL by returning `true`, all rows leak.

**Prevention:**
1. **Always explicitly check for NULL**: `USING (auth.uid() IS NOT NULL AND auth.uid() = user_id)` — from Supabase official docs.
2. **Always specify the role**: Use `TO authenticated` on every policy. This short-circuits the policy evaluation for `anon` role entirely.
3. **Restrict `anon` role access**: Set `REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;` as a blanket protection. No tables should be accessible without authentication.
4. **Security-definer helper function**: The `private.visible_wallet_ids()` function should check `auth.uid() IS NOT NULL` first and return an empty array if null.

**Phase:** Foundation (Phase 1). The security-definer function and anon role restriction should be in the first migration.

**Confidence:** HIGH — Explicitly documented in Supabase RLS docs with yellow warning callouts.

---

### Pitfall 13: XIRR Calculation — Newton-Raphson Non-Convergence

**What goes wrong:** XIRR (Extended Internal Rate of Return) uses Newton-Raphson numerical method to find the discount rate. For certain cash flow patterns — single investment recently started, all-negative cash flows, or very short time periods — the method fails to converge or converges to a nonsensical rate (e.g., 999999% or -100%).

**Prevention:**
1. **Guard the inputs**: XIRR requires at least one positive and one negative cash flow. If the portfolio has no redemptions yet, XIRR is undefined — show absolute return or CAGR instead.
2. **Bounded search**: Constrain Newton-Raphson to a rate between -0.99 (−99%) and 10.0 (1000%). If it exceeds these bounds, fall back to bisection method.
3. **Max iterations with fallback**: Cap at 100 iterations. If not converged, show "Return calculation pending" rather than a wrong number.
4. **Separate from display**: Calculate XIRR in an isolate to avoid blocking the UI. Cache the result — only recalculate when transactions change.

**Phase:** Investments (Phase 7). Unit test with edge cases: single SIP only, very recent investment (<30 days), zero-gain portfolio, extremely high returns.

**Confidence:** MEDIUM — Newton-Raphson convergence failure is well-documented. Exact edge cases depend on implementation.

---

### Pitfall 14: Sync Queue Starvation Under Large Offline Backlog

**What goes wrong:** User is offline for 2 weeks, logging transactions daily. On reconnect, the sync queue has 200+ entries. Processing all at once: (a) hammers Supabase free-tier rate limits, (b) blocks UI responsiveness if sync runs on main isolate, (c) may exceed the 30-second sync window before completing, leading to duplicate processing in the next cycle.

**Prevention:**
1. **Batch size limit**: Process max 20 entries per sync cycle (already in ARCHITECTURE.md). Continue in the next cycle.
2. **Sync in isolate**: Use Dart isolates (Drift supports this) so sync never blocks UI.
3. **Priority ordering**: Schema/structural changes (new wallets, categories) sync before data (transactions). Delete operations at the end (prevent orphans).
4. **Progress indicator**: Show "Syncing 15/200..." instead of just a spinner. User knows it's working.
5. **Deduplicate before sending**: If the same record was updated 5 times offline, only send the latest version. Collapse `UPDATE` + `UPDATE` + `UPDATE` into a single `UPDATE`.

**Phase:** Sync Engine (Phase 4).

---

## Minor Pitfalls

Issues that cause development friction or minor UX problems.

---

### Pitfall 15: Drift Migration Testing — Skipping Schema Tests

**What goes wrong:** Drift provides `make-migrations` with auto-generated tests, but these only verify schema structure. They don't verify data integrity (existing transactions survive the migration with correct values). Developers run `flutter build` and assume migrations are fine because the app compiles.

**Prevention:** Use Drift's `SchemaVerifier` with `schemaAt()` to insert test data at version N, migrate to N+1, and verify the data is intact. Run `validateDatabaseSchema()` in `beforeOpen` during debug builds. Test the full migration chain: v1→v2→v3, not just v2→v3.

**Phase:** Every phase that changes the schema.

---

### Pitfall 16: Indian Number Formatting — Lakhs/Crores Notation

**What goes wrong:** Standard `NumberFormat` formats ₹12,34,567 as ₹1,234,567 (international). Indian users expect ₹12,34,567. The `intl` package supports this via `NumberFormat.currency(locale: 'en_IN')` but it's easy to forget and use the default locale.

**Prevention:** Create a single `formatCurrency(int paise)` utility function used everywhere. Test it with amounts > 1 lakh and > 1 crore. Never call `NumberFormat` directly in widgets.

**Phase:** Core UI (Phase 3). Establish the utility early.

---

### Pitfall 17: Supabase Storage Policies ≠ Table RLS

**What goes wrong:** Supabase Storage uses its own bucket-level policies, separate from table RLS. Having perfect RLS on the `documents` table doesn't protect the actual files in Storage. A user could construct a direct URL to another user's private document if they know the path pattern.

**Prevention:**
1. Storage bucket policies must mirror the wallet-based privacy rules from table RLS.
2. Use the same `private.visible_wallet_ids()` function in storage policies.
3. Include a random UUID component in file paths so they're not guessable from wallet_id alone.
4. Validate file access in the Repository layer on the client before issuing download URLs.

**Phase:** Document Vault (Phase 8).

---

### Pitfall 18: Platform Conditional Imports — SMS on Web Causes Crash

**What goes wrong:** The `telephony` package uses Android platform channels. Importing it unconditionally and calling it on web causes a `MissingPluginException` crash. Even just importing the package on web may cause build errors.

**Prevention:** Use Dart conditional imports (`if (dart.library.ffi)`) to isolate platform-specific code. The SMS service should be behind an abstract interface with a no-op web implementation.

**Phase:** Foundation (Phase 1) for the platform abstraction. SMS Parsing (Phase 9) for the implementation.

---

### Pitfall 19: NAV Data Staleness and Market Holidays

**What goes wrong:** mfapi.in doesn't publish NAV on market holidays (weekends, Diwali, Republic Day, etc.). The "latest NAV" may be 3+ days old. If the app shows "Last updated: 3 days ago" without explanation, users think the app is broken.

**Prevention:**
1. **Show NAV date alongside value**: "NAV: ₹45.67 (as of 14 Mar 2026)".
2. **Don't show "stale" warnings on known market holidays**: Maintain a basic Indian market holiday calendar.
3. **Handle mfapi.in downtime**: The API could be down. Cache the last known NAV locally and show it. Never show ₹0.00 or blank for a fund the user holds.

**Phase:** Investments (Phase 7).

---

### Pitfall 20: SMS Permission on Android 13+ — Default Deny

**What goes wrong:** Android 13 (API 33) and later require explicit user permission to read SMS (`READ_SMS`). The runtime permission prompt can be denied. If denied, the SMS parsing feature silently does nothing — no transactions captured, no error shown.

**Prevention:**
1. **Explain before requesting**: Show a screen explaining why SMS access is needed before the system permission dialog.
2. **Handle denial gracefully**: If denied, show a banner "SMS auto-capture disabled" with a button to re-request or open settings.
3. **Don't block app usage on denial**: The app must be fully functional without SMS permissions — it's a convenience feature, not a requirement.

**Phase:** SMS Parsing (Phase 9).

---

## Phase-Specific Warning Summary

| Phase | Likely Pitfall | Severity | Mitigation |
|-------|---------------|----------|------------|
| Phase 1: Foundation | RLS gaps (#3, #12), schema design for integers (#2) | Critical | Auto-enable RLS trigger, integer money from day 1 |
| Phase 2: Core Data | Stored balance (#11), transfer atomicity (#7) | Critical | Derived balances, transfer_ref grouping |
| Phase 3: Core UI | Number formatting (#16) | Minor | Central `formatCurrency()` utility |
| Phase 4: Sync Engine | Sync loop (#1), FK ordering (#4), clock skew (#5), backlog (#14), web data loss (#6) | Critical | Separate timestamps, dependency-aware queue, server timestamps |
| Phase 7: Investments | XIRR convergence (#13), NAV staleness (#19) | Moderate | Bounded Newton-Raphson, holiday calendar |
| Phase 8: Documents | Storage policies (#17) | Moderate | Mirror RLS in bucket policies |
| Phase 9: SMS Parsing | Format fragility (#9), Android permissions (#20), web crashes (#18) | Moderate | Parser registry, graceful permission handling, conditional imports |
| Phase 10: Polish | Free-tier limits (#10) | Moderate | Keep-alive cron, exponential backoff |

---

## Technical Debt Patterns to Avoid

| Pattern | Why It's Tempting | Why It's Debt | What To Do Instead |
|---------|-------------------|---------------|--------------------|
| `double` for money | Quick, Dart-native | Accumulating precision errors | Integer paise from day 1 |
| Stored wallet balance | Fast reads | Diverges from transaction sum | Computed SUM queries with Drift `watch()` |
| Single `updated_at` for sync | Simple | Creates sync loops | Separate `updated_at` + `synced_at` columns |
| Mega-regex for all bank SMS | One regex to rule them all | Breaks on any format change | Per-bank parser registry |
| Direct Supabase calls from UI | "Just works" quickly | Bypasses offline-first, bypasses privacy | Repository → DAO → Local DB always |
| Skip RLS tests in CI | "Works in manual testing" | One missed table = privacy breach | pgTAP test asserting RLS on every table |
| Ignore Drift migration tests | "Schema is simple" | Untested migration = user data loss on update | `make-migrations` auto-tests + data integrity tests |

---

## Sources

- Drift migrations: https://drift.simonbinder.eu/Migrations/ — **HIGH confidence**
- Drift migration testing: https://drift.simonbinder.eu/Migrations/tests/ — **HIGH confidence**
- Drift web platform: https://drift.simonbinder.eu/platforms/web/ — **HIGH confidence**
- Supabase RLS docs: https://supabase.com/docs/guides/database/postgres/row-level-security — **HIGH confidence**
- Supabase pricing: https://supabase.com/pricing — **HIGH confidence** (free tier: 500MB DB, 1GB storage, 5GB egress, pauses after 1 week)
- Flutter web building: https://docs.flutter.dev/platform-integration/web/building — **HIGH confidence**
- IEEE 754 floating-point: universally documented — **HIGH confidence**
- XIRR Newton-Raphson convergence: numerical methods literature — **MEDIUM confidence** (edge cases vary by implementation)
- Indian bank SMS formats: Industry knowledge from fintech community — **HIGH confidence** (formats documented by CRED, Jupiter, 1Money app communities)
