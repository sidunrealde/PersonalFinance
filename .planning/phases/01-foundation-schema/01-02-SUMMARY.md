---
phase: 01-foundation-schema
plan: 02
subsystem: database
tags: [supabase, postgresql, rls, pgtap, migration, privacy-wall]

requires:
  - phase: 01-01
    provides: "Flutter project scaffold with Supabase dependency"
provides:
  - "Complete PostgreSQL schema for all 12 phases (~30 tables)"
  - "RLS Privacy Wall enforcing private wallet isolation"
  - "Helper functions: visible_wallet_ids(), user_household_id()"
  - "accept_invite() RPC for household joining flow"
  - "handle_new_user() trigger for auto-profile creation"
  - "set_server_updated_at trigger on all tables"
  - "Auto-RLS event trigger for new tables"
  - "pgTAP test suite proving privacy isolation (19 tests)"
affects: [01-03-drift-local-db, 01-05-auth-onboarding, all-future-phases]

tech-stack:
  added: [supabase-cli, pgtap, pgcrypto]
  patterns: [visible_wallet_ids-privacy-wall, security-definer-helpers, auto-rls-event-trigger, integer-paise-bigint]

key-files:
  created:
    - supabase/config.toml
    - supabase/migrations/00000000000000_init_schema.sql
    - supabase/migrations/00000000000001_future_features.sql
    - supabase/migrations/00000000000002_helpers_triggers.sql
    - supabase/migrations/00000000000003_rls_policies.sql
    - supabase/tests/rls_privacy_test.sql
    - supabase/tests/wallet_creation_test.sql
    - supabase/tests/invite_test.sql
  modified: []

key-decisions:
  - "Used ANY(private.visible_wallet_ids()) without SELECT wrapper for array comparisons — SELECT wrapper causes uuid vs uuid[] type mismatch with ANY()"
  - "sip_schedules handled as child table via holding_id→investment_holdings, not wallet-scoped"
  - "Supabase config: PostgreSQL 17, auth signup enabled, email confirmations disabled for local dev"

patterns-established:
  - "Privacy Wall: visible_wallet_ids() SECURITY DEFINER function returns only wallets user can access"
  - "Wallet-scoped RLS: wallet_id = ANY(private.visible_wallet_ids()) for all wallet-linked tables"
  - "User-scoped RLS: user_id = (SELECT auth.uid()) for user-only tables"
  - "Household-scoped RLS: household_id = (SELECT private.user_household_id()) for household tables"
  - "Child table RLS: parent FK IN (SELECT id FROM parent WHERE visible) pattern"
  - "Auto-RLS event trigger: any new public table auto-gets deny-all RLS"
  - "Integer paise: ALL monetary columns are BIGINT, never FLOAT/NUMERIC"

requirements-completed: [AUTH-05, WALL-01, WALL-02]

duration: 25min
completed: 2026-03-18
---

# Phase 1 Plan 2: Supabase Schema + RLS + pgTAP Summary

**Complete PostgreSQL schema for all 12 phases (~30 tables) with RLS Privacy Wall enforcing private wallet isolation, verified by 19 pgTAP tests**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-03-18T12:10:25Z
- **Completed:** 2026-03-18T12:35:00Z
- **Tasks:** 2/2
- **Files created:** 8

## Accomplishments
- Created 4 SQL migrations covering all ~30 tables for all 12 project phases
- Implemented complete RLS Privacy Wall: User A provably cannot see User B's private wallet data
- Built accept_invite() RPC that atomically adds member, creates wallet, seeds 8 categories
- All 19 pgTAP tests pass: privacy isolation (10), wallet creation (5), invite edge cases (4)
- Auto-RLS event trigger ensures any future table gets deny-all RLS by default

## Task Commits

1. **Task 1: Supabase init + core schema + future feature tables** - `60b4118` (feat)
2. **Task 2: Helper functions, RLS policies, and pgTAP tests** - `b45eb51` (feat)

## Files Created
- `supabase/config.toml` - Supabase local dev config (PG 17, auth settings)
- `supabase/migrations/00000000000000_init_schema.sql` - Phase 1 active tables: profiles, households, household_members, household_invites, wallets, wallet_categories
- `supabase/migrations/00000000000001_future_features.sql` - ~25 future-feature tables (transactions through sync_log)
- `supabase/migrations/00000000000002_helpers_triggers.sql` - Helper functions, triggers, accept_invite RPC
- `supabase/migrations/00000000000003_rls_policies.sql` - Complete RLS policies for all tables
- `supabase/tests/rls_privacy_test.sql` - 10 pgTAP tests: User A/B private wallet isolation + structural RLS checks
- `supabase/tests/wallet_creation_test.sql` - 5 pgTAP tests: accept_invite creates wallet + categories
- `supabase/tests/invite_test.sql` - 4 pgTAP tests: expired/accepted/revoked invites rejected

## Decisions Made
- **ANY() syntax**: Used `ANY(private.visible_wallet_ids())` without `(SELECT ...)` wrapper. The SELECT wrapper causes a type mismatch (`uuid = uuid[]`) with `ANY()`. Direct function call works correctly.
- **sip_schedules as child table**: sip_schedules doesn't have wallet_id directly; it references investment_holdings via holding_id. Handled as a child table policy (join through parent) rather than wallet-scoped.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] ANY() type mismatch with SELECT wrapper**
- **Found during:** Task 2 (RLS policies)
- **Issue:** `id = ANY((SELECT private.visible_wallet_ids()))` caused `operator does not exist: uuid = uuid[]` — PostgreSQL couldn't resolve the ANY with a subquery returning an array
- **Fix:** Changed to `id = ANY(private.visible_wallet_ids())` — direct function call instead of subquery
- **Files modified:** supabase/migrations/00000000000003_rls_policies.sql
- **Verification:** `npx supabase start` applies all 4 migrations cleanly

**2. [Rule 1 - Bug] sip_schedules missing wallet_id column**
- **Found during:** Task 2 (RLS policies)
- **Issue:** sip_schedules was in the wallet-scoped DO loop but has holding_id, not wallet_id
- **Fix:** Removed from wallet-scoped loop, added child table policy via holding_id→investment_holdings
- **Files modified:** supabase/migrations/00000000000003_rls_policies.sql
- **Verification:** All 19 pgTAP tests pass

---

**Total deviations:** 2 auto-fixed (Rule 1: bug fixes)
**Impact on plan:** Both fixes necessary for correctness. No scope creep.

## Issues Encountered
- Docker Desktop was not running initially. Started it programmatically. No impact on work.

## User Setup Required
None - Supabase runs locally via Docker. No external service accounts needed for this plan.

## Next Phase Readiness
- Schema is complete and verified. All tables for all 12 phases exist.
- RLS policies enforced and tested. Privacy Wall is proven.
- Ready for Plan 01-03 (Drift local DB) to mirror this schema in SQLite.
- Ready for Plan 01-05 (Auth + onboarding) to use accept_invite() and handle_new_user().

## Self-Check: PASSED

All 8 created files verified to exist. Both commit hashes (60b4118, b45eb51) verified in git log. All 19 pgTAP tests passing.

---
*Phase: 01-foundation-schema*
*Completed: 2026-03-18*
