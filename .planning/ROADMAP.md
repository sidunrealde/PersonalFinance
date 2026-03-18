# Roadmap: Household Financial & Life Organizer

## Overview

This roadmap delivers a complete household finance and life organizer through 12 phases following the dependency graph: Foundation → Data Layer → UI → Sync → Feature phases → Analytics → Life Organizer. The Privacy Wall is established in Phases 1-2 before any feature code touches wallet data. The Sync Engine (Phase 4) is built before feature-heavy phases so every feature benefits from offline-first from day one. Feature phases (5-10) build on the solid data + sync foundation. Analytics comes after all data sources exist. Life Organizer caps the project.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Foundation & Schema** - Supabase + Flutter scaffold, auth, RLS Privacy Wall, wallet creation
- [ ] **Phase 2: Core Data Layer & Privacy Wall** - Repositories, DAOs, transactions, transfers, splits, categories
- [ ] **Phase 3: Core UI & Ledger** - Dashboard, quick-add, presets, search/filter, dual view
- [ ] **Phase 4: Sync Engine** - Offline-first with Drift↔Supabase polling sync, backup/restore
- [ ] **Phase 5: Budgets & Recurring** - Category budgets, alerts, recurring transactions, notifications
- [ ] **Phase 6: Shopping Lists** - Named lists, wallet linking, auto-deduct, estimated vs actual
- [ ] **Phase 7: Investment Tracking** - MF + stock portfolio, NAV/price fetch, SIP calendar, XIRR
- [ ] **Phase 8: Document Vault** - Receipts, standalone docs, image/PDF upload, warranty alerts
- [ ] **Phase 9: SMS Auto-Capture** - Bank/UPI SMS parsing, backfill, smart rules, merchant learning
- [ ] **Phase 10: Debt, EMI & Loans** - EMI tracker, loans given/received, debt dashboard
- [ ] **Phase 11: Analytics & Insights** - Charts, trends, merchant analysis, net worth, deep analytics
- [ ] **Phase 12: Goals & Life Organizer** - Financial goals, task lists, calendar, subscriptions, summary widget

## Phase Details

### Phase 1: Foundation & Schema
**Goal**: Secure infrastructure backbone — database schema, auth, RLS policies, wallet structure, and cross-platform Flutter app that builds on Android and Web
**Depends on**: Nothing (first phase)
**Requirements**: AUTH-01, AUTH-02, AUTH-03, AUTH-04, AUTH-05, WALL-01, WALL-02, PLAT-05
**Success Criteria** (what must be TRUE):
  1. User can sign up with email/password, log in, stay logged in across sessions, and log out
  2. New user automatically gets a private wallet; can create or join a household via invite code
  3. Shared wallet + private wallets exist with RLS policies that provably prevent User A from seeing User B's private data (verified by SQL test)
  4. All monetary values stored as integer paise in the database (not floating point)
  5. Flutter app builds and runs on both Android emulator and Web browser from single codebase
**Plans:** 1/5 plans executed
Plans:
- [ ] 01-01-PLAN.md — Flutter project scaffold + core infrastructure
- [ ] 01-02-PLAN.md — Supabase schema + RLS Privacy Wall + pgTAP tests
- [ ] 01-03-PLAN.md — Drift Phase 1 active tables + DAOs + code generation
- [ ] 01-04-PLAN.md — Drift future-feature table definitions + full schema
- [ ] 01-05-PLAN.md — Auth flow + household invite + onboarding wizard

### Phase 2: Core Data Layer & Privacy Wall
**Goal**: Repository + DAO layer with privacy enforcement at every operation, plus wallet transfers, split transactions, and per-wallet categories
**Depends on**: Phase 1
**Requirements**: WALL-03, WALL-04, WALL-05, WALL-07, TXNS-01, TXNS-05
**Success Criteria** (what must be TRUE):
  1. User can create, read, update, and delete income/expense transactions in their wallets
  2. User can transfer funds in all directions (shared↔private, private↔private) with paired ledger entries visible correctly per privacy rules
  3. User can split a single expense across shared and private wallets creating linked entries
  4. Each wallet has its own customizable categories; private wallet categories are invisible to the other user
  5. All amounts display in ₹ with Indian lakhs/crores formatting (₹1,23,456.78)
**Plans**: TBD

### Phase 3: Core UI & Ledger
**Goal**: User-facing screens for daily transaction management — dashboard with wallet switching, quick expense entry, presets, and search/filter
**Depends on**: Phase 2
**Requirements**: TXNS-02, TXNS-03, TXNS-04, WALL-06
**Success Criteria** (what must be TRUE):
  1. User can toggle between unified feed, shared dashboard, and private dashboard views
  2. User can add expenses via quick-add form (amount + category selection) in under 5 seconds
  3. User can create and use one-click presets for frequent expenses (e.g., "Morning Coffee ₹30" → one tap)
  4. User can search and filter transactions by date range, category, wallet, amount range, and keyword
**Plans**: TBD

### Phase 4: Sync Engine
**Goal**: Offline-first architecture where local Drift DB is source of truth, with reliable push/pull sync to Supabase via polling and LWW conflict resolution
**Depends on**: Phase 2
**Requirements**: PLAT-01, PLAT-02, PLAT-03, PLAT-04
**Success Criteria** (what must be TRUE):
  1. All existing features work fully offline — user can create, edit, delete transactions without internet
  2. When connection returns, local changes push to cloud and remote changes pull to local within 30 seconds
  3. When both users edit the same transaction offline, last-write-wins resolves using server timestamp without data loss
  4. User can export a local backup and restore data from cloud backup
  5. Sync queue handles FK dependencies correctly (parent records sync before children)
**Plans**: TBD

### Phase 5: Budgets & Recurring
**Goal**: Monthly category budgets with threshold alerts and auto-recurring transaction engine with notification infrastructure
**Depends on**: Phase 4
**Requirements**: BUDG-01, BUDG-02, BUDG-03, BUDG-04, PLAT-06
**Success Criteria** (what must be TRUE):
  1. User can set monthly budget per category per wallet and see a progress bar of spending
  2. Push notification + in-app badge fires when category budget hits 80% and 100%
  3. Recurring transactions (rent, EMIs, subscriptions) auto-create on their configured due date
  4. User receives bill due date reminders 3 days and 1 day before
  5. Notification infrastructure operational for budget, recurring, and future feature notifications
**Plans**: TBD

### Phase 6: Shopping Lists
**Goal**: Shopping list management with wallet linking and automated budget deduction on purchase
**Depends on**: Phase 5
**Requirements**: SHOP-01, SHOP-02, SHOP-03, SHOP-04, SHOP-05
**Success Criteria** (what must be TRUE):
  1. User can create multiple named shopping lists with items and estimated costs
  2. Each list is linked to a wallet (shared or private) that determines where deductions go
  3. Marking an item as "purchased" auto-creates an expense transaction in the linked wallet
  4. User can compare estimated vs actual cost per item and per list after shopping
  5. Before shopping, user sees budget impact preview (e.g., "40% of remaining grocery budget")
**Plans**: TBD

### Phase 7: Investment Tracking
**Goal**: Complete mutual fund and stock portfolio tracking with automated pricing, SIP management, XIRR calculations, and historical charts
**Depends on**: Phase 4
**Requirements**: INVS-01, INVS-02, INVS-03, INVS-04, INVS-05, INVS-06, INVS-07, INVS-08, INVS-09, INVS-10
**Success Criteria** (what must be TRUE):
  1. User can add/view/edit mutual fund and stock holdings per wallet
  2. Mutual fund NAV auto-updates daily (mfapi.in); stock prices auto-update daily
  3. User can manually override any auto-fetched price/NAV
  4. SIP schedule visible on a calendar with upcoming debit dates
  5. Portfolio view shows per-fund/stock breakdown: invested value, current value, gain/loss (₹ and %)
  6. XIRR calculated per fund, per wallet, and portfolio-level with time-weighted accuracy
  7. Historical portfolio value chart displays over customizable time ranges
**Plans**: TBD

### Phase 8: Document Vault
**Goal**: Receipt and document storage with file upload, privacy enforcement, and warranty expiry tracking
**Depends on**: Phase 4
**Requirements**: DOCS-01, DOCS-02, DOCS-03, DOCS-04, DOCS-05, DOCS-06
**Success Criteria** (what must be TRUE):
  1. User can attach images/PDFs (up to 5MB) to specific transactions as receipts
  2. User can store standalone documents (manuals, warranties) with name, category, and expiry date
  3. Documents sync to cloud storage through the sync queue
  4. User receives an alert 30 days before a warranty expires
  5. User can search documents by name or category
  6. Document visibility follows wallet privacy rules — private wallet docs invisible to partner
**Plans**: TBD

### Phase 9: SMS Auto-Capture
**Goal**: Android-only SMS parsing that auto-captures bank/UPI transactions with smart merchant categorization and deduplication
**Depends on**: Phase 5
**Requirements**: SMS-01, SMS-02, SMS-03, SMS-04, SMS-05
**Success Criteria** (what must be TRUE):
  1. App reads bank/UPI SMS and correctly extracts amount, merchant/payee, date, and reference number
  2. On app open, all SMS since last processed timestamp are scanned — zero missed transactions
  3. Duplicate transactions prevented: same reference number never creates two entries
  4. Known merchants (Swiggy, BigBasket, etc.) auto-categorize; unknown merchants create drafts for user review
  5. When user categorizes a draft, the merchant→category mapping is saved and used for future SMS from that merchant
**Plans**: TBD

### Phase 10: Debt, EMI & Loans
**Goal**: Comprehensive debt tracking — EMIs/loans taken, money lent/borrowed, with auto-recurring integration and overview dashboard
**Depends on**: Phase 5
**Requirements**: DEBT-01, DEBT-02, DEBT-03, DEBT-04, DEBT-05
**Success Criteria** (what must be TRUE):
  1. User can track active EMIs/loans with amount, principal, interest rate, tenure, and payment schedule
  2. User can track loans given to others with borrower, amount, date, and partial repayment tracking
  3. User can track loans received from others with lender, amount, date, and repayment plan
  4. EMI payments auto-log as recurring expense transactions on due date
  5. Debt overview dashboard shows total owed, total lent, and upcoming EMI payments
**Plans**: TBD

### Phase 11: Analytics & Insights
**Goal**: Deep financial analytics with charts, trends, comparisons, and net worth tracking across all financial data
**Depends on**: Phase 7, Phase 10
**Requirements**: ANLY-01, ANLY-02, ANLY-03, ANLY-04, ANLY-05, ANLY-06, ANLY-07, ANLY-08
**Success Criteria** (what must be TRUE):
  1. User can view category-wise spending charts (pie/bar) for any wallet or time period
  2. Budget vs actual spending comparison displayed per category with clear visualization
  3. User can select custom date ranges and compare spending across periods
  4. Spending trends visible over time (month-over-month, quarter-over-quarter)
  5. Merchant-level analysis ranks merchants by total spend (powered by SMS data when available)
  6. Net worth displays all wallet balances + portfolio value in a single view
**Plans**: TBD

### Phase 12: Goals & Life Organizer
**Goal**: Financial goals with progress tracking plus household life organization — tasks, unified calendar, subscription tracker, and daily summary
**Depends on**: Phase 5, Phase 7
**Requirements**: GOAL-01, GOAL-02, GOAL-03, GOAL-04, LIFE-01, LIFE-02, LIFE-03, LIFE-04, LIFE-05
**Success Criteria** (what must be TRUE):
  1. User can create shared goals (linked to shared wallet) and private goals (invisible to partner)
  2. Goal progress shown with visual bars and contribution history; timeline projection shows estimated completion date
  3. User can create household task lists with assignable tasks and completion tracking
  4. Unified calendar shows SIP debits, bill dues, task deadlines, warranty expiries, EMI dates, and custom events
  5. User can track subscriptions with monthly costs and track important dates with annual reminders
  6. Daily/weekly summary widget shows today's tasks, upcoming bills, SIP debits, and financial highlights
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 11 → 12

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation & Schema | 1/5 | In Progress|  |
| 2. Core Data Layer & Privacy Wall | 0/? | Not started | - |
| 3. Core UI & Ledger | 0/? | Not started | - |
| 4. Sync Engine | 0/? | Not started | - |
| 5. Budgets & Recurring | 0/? | Not started | - |
| 6. Shopping Lists | 0/? | Not started | - |
| 7. Investment Tracking | 0/? | Not started | - |
| 8. Document Vault | 0/? | Not started | - |
| 9. SMS Auto-Capture | 0/? | Not started | - |
| 10. Debt, EMI & Loans | 0/? | Not started | - |
| 11. Analytics & Insights | 0/? | Not started | - |
| 12. Goals & Life Organizer | 0/? | Not started | - |
