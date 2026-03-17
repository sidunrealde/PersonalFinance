---
phase: 01
slug: foundation-schema
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-17
---

# Phase 01 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | pgTAP (SQL) for RLS/DB tests + Flutter test for Dart unit/integration |
| **Config file** | `supabase/tests/` (pgTAP), `test/` (Flutter) |
| **Quick run command** | `supabase test db` |
| **Full suite command** | `supabase test db && flutter test` |
| **Estimated runtime** | ~30 seconds |

---

## Sampling Rate

- **After every task commit:** Run `supabase test db`
- **After every plan wave:** Run `supabase test db && flutter test && flutter build apk --debug && flutter build web`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 30 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 01-01-01 | 01 | 1 | AUTH-01 | integration | `flutter test test/integration/auth_signup_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-02 | 01 | 1 | AUTH-02 | integration | `flutter test test/integration/auth_session_test.dart` | ❌ W0 | ⬜ pending |
| 01-01-03 | 01 | 1 | AUTH-03 | unit | `flutter test test/unit/auth_service_test.dart` | ❌ W0 | ⬜ pending |
| 01-02-01 | 02 | 1 | AUTH-04 | SQL+integration | `supabase test db` | ❌ W0 | ⬜ pending |
| 01-02-02 | 02 | 1 | AUTH-05 | SQL | `supabase test db` | ❌ W0 | ⬜ pending |
| 01-03-01 | 03 | 1 | WALL-01 | SQL+unit | `supabase test db && flutter test test/unit/wallet_dao_test.dart` | ❌ W0 | ⬜ pending |
| 01-03-02 | 03 | 1 | WALL-02 | SQL | `supabase test db` (impersonation tests) | ❌ W0 | ⬜ pending |
| 01-04-01 | 04 | 1 | PLAT-05 | build | `flutter build apk --debug && flutter build web` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `supabase/tests/rls_privacy_test.sql` — RLS impersonation tests for WALL-02
- [ ] `supabase/tests/invite_acceptance_test.sql` — invite flow for AUTH-04
- [ ] `supabase/tests/wallet_creation_test.sql` — auto-wallet creation for WALL-01
- [ ] `test/unit/wallet_dao_test.dart` — Drift wallet DAO tests for WALL-01
- [ ] `test/unit/auth_service_test.dart` — auth service logout for AUTH-03
- [ ] `test/integration/auth_signup_test.dart` — signup flow for AUTH-01
- [ ] `test/integration/auth_session_test.dart` — session persistence for AUTH-02
- [ ] pgTAP extension: `CREATE EXTENSION IF NOT EXISTS "pgtap"` in first migration

*Wave 0 creates test stubs that fail (RED). Tasks make them pass (GREEN).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Flutter app renders on Android emulator | PLAT-05 | Emulator UI verification | Launch `flutter run` on Android emulator, verify app loads |
| Flutter app renders on Web browser | PLAT-05 | Browser UI verification | Launch `flutter run -d chrome`, verify app loads |
| Onboarding wizard flow | AUTH-04 | Multi-step UI interaction | Walk through signup → household creation → invite generation |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 30s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
