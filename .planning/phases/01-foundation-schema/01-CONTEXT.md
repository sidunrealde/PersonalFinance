# Phase 1: Foundation & Schema - Context

**Gathered:** 2026-03-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Secure infrastructure backbone — database schema (full schema for all future features), Supabase auth, RLS Privacy Wall policies, wallet structure, household creation/joining, and cross-platform Flutter app that builds on Android and Web. No transaction UI, no budgets, no features — just the foundation.

</domain>

<decisions>
## Implementation Decisions

### Household Joining Flow
- Magic link invite: first user creates household during guided setup, generates a magic link to share with partner (email/WhatsApp)
- Link expires after 7 days; first user can regenerate anytime
- Second user clicks link → signs up → auto-joins the household
- Leave and re-invite allowed: either member can leave; the other can invite a new partner
- Household is user-named during onboarding (e.g., "The Patels")

### First User Onboarding
- Full guided setup after signup: household name, invite partner step, initial wallet creation, sample default categories
- Onboarding wizard walks through setup before landing on dashboard

### Wallet Structure
- Fixed 3 wallets per household: one shared wallet + one private wallet per user
- No custom wallets — the three wallets are auto-created when household is formed
- Shared wallet is visible to both members; private wallets are strictly isolated

### Category Setup
- Preset categories installed on every new wallet: Food, Transport, Shopping, Bills, Health, Entertainment, Education, Miscellaneous
- Users can rename, add, or remove categories later (Phase 2+ handles CRUD)

### Schema Approach
- Full schema upfront: create ALL tables for ALL future features in Phase 1 (transactions, budgets, goals, investments, documents, shopping lists, debt, life organizer, etc.)
- Avoids complex migrations in later phases — tables start empty, features populate them as phases are executed

### RLS Policy Approach
- RLS enabled on privacy-sensitive tables only (wallets, transactions, categories, documents, investments, goals, debt, etc.)
- Shared-only tables (households, household_members) skip RLS — accessible to all household members
- User-based RLS: `user_id` on every privacy-sensitive row; policy checks user owns this row OR row belongs to shared wallet AND user is household member
- Auto-enable trigger: any new table automatically gets a deny-all RLS policy; developer must explicitly add allow policies
- SQL assertion tests: automated tests that impersonate User A and attempt to query User B's private data, asserting zero rows returned

### Claude's Discretion
- JWT token refresh strategy and session duration
- Supabase Edge Function usage vs client-side logic
- Specific Drift schema migration approach
- Flutter project structure (feature-first vs layer-first)
- go_router route hierarchy

</decisions>

<specifics>
## Specific Ideas

- Research recommended Flutter + Drift + Supabase stack — user confirmed flexibility but accepted this recommendation
- Integer paise for ALL monetary columns (not float)
- Separate `updated_at` and `synced_at` columns to prevent sync loops (from research pitfalls)
- Client-side UUIDs for all primary keys (enables offline record creation)
- `transfer_ref` UUID column for atomic wallet transfers
- RLS auto-enable trigger from research: `CREATE EVENT TRIGGER` on `ddl_command_end` that enables RLS on new tables

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- None — greenfield project, no existing code

### Established Patterns
- None yet — this phase establishes all foundational patterns

### Integration Points
- Supabase project setup (requires Supabase CLI or dashboard)
- Flutter SDK installation and project scaffolding
- Drift code generation setup (build_runner)

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-schema*
*Context gathered: 2026-03-17*
