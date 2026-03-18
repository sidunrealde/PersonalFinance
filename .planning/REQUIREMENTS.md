# Requirements: Household Financial & Life Organizer

**Defined:** 2026-03-17
**Core Value:** The Privacy Wall — shared household wallet for joint expenses with strictly isolated private wallets where personal finances remain invisible to the other person.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Authentication & Security

- [ ] **AUTH-01**: User can sign up with email and password
- [ ] **AUTH-02**: User can log in and stay logged in across browser/app sessions (JWT refresh tokens)
- [ ] **AUTH-03**: User can log out from any screen
- [ ] **AUTH-04**: User can create or join a household via invite link/code
- [ ] **AUTH-05**: All data encrypted in transit (TLS) and sensitive fields encrypted at rest

### Privacy Wall & Wallets

- [ ] **WALL-01**: Each household has one shared wallet and one private wallet per user, created automatically on signup
- [ ] **WALL-02**: Private wallet data (transactions, categories, balances, documents) is NEVER visible to the other household member — enforced at DB (RLS), repository, and UI layers
- [ ] **WALL-03**: User can transfer funds in all directions — shared→private, private→shared, private→private
- [ ] **WALL-04**: Transfers create paired ledger entries (outgoing in source, incoming in destination); only transfer amount visible to other user for private wallets
- [ ] **WALL-05**: User can split a single expense across wallets (e.g., ₹2000 dinner → ₹1500 shared + ₹500 personal)
- [ ] **WALL-06**: User can view unified feed (all visible wallets) or separate shared/private dashboards
- [ ] **WALL-07**: Each wallet has its own customizable expense/income categories

### Transaction Management

- [ ] **TXNS-01**: User can create, read, update, and delete income and expense transactions with amount, category, date, and note
- [ ] **TXNS-02**: User can quickly add expenses via a fast form with amount + category selection
- [ ] **TXNS-03**: User can create one-click presets for frequent expenses (e.g., "Morning Coffee ₹30")
- [ ] **TXNS-04**: User can search and filter transactions by date range, category, wallet, amount range, and keyword
- [ ] **TXNS-05**: All monetary amounts displayed in INR with Indian number formatting (₹1,23,456.78 — lakhs/crores)

### Budgets & Recurring

- [ ] **BUDG-01**: User can set monthly budget limits per category per wallet with progress bars
- [ ] **BUDG-02**: User receives alerts (push notification + in-app badge) when a category budget reaches 80% and 100%
- [ ] **BUDG-03**: User can create recurring transactions (rent, EMIs, subscriptions) with configurable frequency (daily/weekly/monthly/yearly) that auto-log on due date
- [ ] **BUDG-04**: User receives bill due date reminders 3 days and 1 day before due date

### Shopping Lists

- [ ] **SHOP-01**: User can create multiple named shopping lists (hardware, groceries, furniture) with items and estimated costs
- [ ] **SHOP-02**: Each shopping list is linked to a specific wallet (shared or private) for budget deduction
- [ ] **SHOP-03**: Marking a list item as "purchased" auto-creates an expense transaction in the linked wallet using the item's actual cost
- [ ] **SHOP-04**: User can compare estimated vs actual cost per item and per list after shopping
- [ ] **SHOP-05**: User can preview total list budget impact before shopping (e.g., "this list will use 40% of remaining grocery budget")

### Investment & Wealth Tracking

- [ ] **INVS-01**: User can track mutual fund holdings per wallet with units, NAV, and current value
- [ ] **INVS-02**: App auto-fetches daily NAV for mutual funds (via mfapi.in) with manual override option
- [ ] **INVS-03**: User can track stock holdings per wallet with shares, price, and current value
- [ ] **INVS-04**: App auto-fetches daily stock prices with manual override option
- [ ] **INVS-05**: User can track SIPs with amount, frequency, and auto-debit dates
- [ ] **INVS-06**: User can view a SIP calendar showing upcoming auto-debit dates
- [ ] **INVS-07**: User can view full portfolio — per-fund/stock breakdown with invested value, current value, and gains/losses (absolute + percentage)
- [ ] **INVS-08**: App calculates XIRR (time-weighted returns) per fund, per wallet, and portfolio-level
- [ ] **INVS-09**: User can view historical portfolio value charts over time
- [ ] **INVS-10**: Investment privacy follows wallet rules — shared investments visible to both, private investments visible only to owner

### Document Vault

- [ ] **DOCS-01**: User can attach receipt images/PDFs to specific transactions
- [ ] **DOCS-02**: User can store standalone documents (appliance manuals, warranty cards) with metadata (name, category, expiry date)
- [ ] **DOCS-03**: App supports image + PDF uploads with a 5MB per-file limit
- [ ] **DOCS-04**: User receives alerts when a warranty is about to expire (30 days before)
- [ ] **DOCS-05**: User can search documents by name or category
- [ ] **DOCS-06**: Document visibility follows wallet privacy rules — shared wallet documents visible to both, private wallet documents visible only to owner

### SMS Auto-Capture (Android)

- [ ] **SMS-01**: App parses incoming bank/UPI SMS notifications to extract transaction amount, merchant/payee, date, and reference number
- [ ] **SMS-02**: On app open, app scans all bank/UPI SMS since last processed timestamp — zero missed transactions even if app was closed for days
- [ ] **SMS-03**: Duplicate transactions prevented using transaction reference number matching
- [ ] **SMS-04**: Known merchants auto-categorize into the correct category; unknown merchants create draft transactions for user review
- [ ] **SMS-05**: App learns from user corrections — when user categorizes a draft, the merchant→category mapping is saved for future auto-categorization

### Analytics & Insights

- [ ] **ANLY-01**: User can view category-wise spending charts (pie/bar) for any wallet
- [ ] **ANLY-02**: User can view budget vs actual spending comparison per category with visualization
- [ ] **ANLY-03**: User can select custom date ranges and compare spending across time periods
- [ ] **ANLY-04**: User can view spending trends over time (month-over-month, quarter-over-quarter)
- [ ] **ANLY-05**: User can view merchant-level spending analysis (rank merchants by spend)
- [ ] **ANLY-06**: User can view shared vs personal spending ratio
- [ ] **ANLY-07**: User can view income vs expense cash flow per month with trend line
- [ ] **ANLY-08**: User can view net worth (all wallet balances + portfolio value)

### Financial Goals

- [ ] **GOAL-01**: User can create shared financial goals linked to the shared wallet (e.g., "Save ₹5L for house setup")
- [ ] **GOAL-02**: User can create private financial goals linked to their private wallet (invisible to partner)
- [ ] **GOAL-03**: User can view goal progress with visual progress bars and contribution history
- [ ] **GOAL-04**: App projects goal timeline — "at current savings rate, you'll reach this by [date]"

### Debt, EMI & Loans

- [ ] **DEBT-01**: User can track active EMIs/loans taken (car loan, home loan, personal loan) with EMI amount, remaining principal, interest rate, tenure, and payment schedule
- [ ] **DEBT-02**: User can track loans given to others (who, amount, when, expected return date, partial repayments)
- [ ] **DEBT-03**: User can track loans received from others (from whom, amount, when, repayment plan)
- [ ] **DEBT-04**: EMI payments auto-log as recurring expense transactions on due date
- [ ] **DEBT-05**: User can view a debt overview dashboard — total owed, total lent, upcoming EMI payments

### Life Organizer

- [ ] **LIFE-01**: User can create household task lists with assignable tasks (chore assignment, completion tracking)
- [ ] **LIFE-02**: User can view a unified calendar showing SIP debits, bill dues, task deadlines, warranty expiries, EMI dates, and custom events in one view
- [ ] **LIFE-03**: User can track active subscriptions (Netflix, Spotify, gym) with monthly costs and renewal dates
- [ ] **LIFE-04**: User can track important dates (birthdays, anniversaries, renewal dates) with annual reminders
- [ ] **LIFE-05**: User sees a daily/weekly summary widget — today's tasks, upcoming bills, SIP debits, and financial highlights

### Platform & Infrastructure

- [ ] **PLAT-01**: App works fully offline — all features functional without internet, changes sync when connection returns
- [ ] **PLAT-02**: Near real-time sync via polling when online — partner's changes appear within seconds
- [ ] **PLAT-03**: Last-write-wins conflict resolution for concurrent offline edits
- [ ] **PLAT-04**: Both local backup (exportable) and cloud backup for data safety
- [x] **PLAT-05**: Single codebase builds Android app + Web app (cross-platform)
- [ ] **PLAT-06**: All notifications — budget alerts, recurring reminders, SIP dates, shared wallet activity, warranty expiry, bill reminders

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Analytics

- **ANLY-V2-01**: Year-end financial summary (earned, spent, saved, portfolio growth)
- **ANLY-V2-02**: Recurring task support with auto-creation on completion

### Advanced Investments

- **INVS-V2-01**: LTCG/STCG tax implication flags for investment holdings
- **INVS-V2-02**: Rebalancing alerts when asset allocation drifts from target
- **INVS-V2-03**: Dividend/payout tracking for mutual funds and stocks
- **INVS-V2-04**: SIP step-up tracking (annual SIP amount increases)

### Life Organizer Extended

- **LIFE-V2-01**: Household inventory tracking (major purchases, warranty status)
- **LIFE-V2-02**: Maintenance schedule tracking (AC service every 6 months, etc.)
- **LIFE-V2-03**: Seasonal/annual planning (Diwali budget, tax season, etc.)
- **LIFE-V2-04**: Emergency contacts & household info storage
- **LIFE-V2-05**: Household document checklist (passport validity, Aadhaar status, PAN filing)

### Net Worth Liability

- **DEBT-V2-01**: Net worth integration — liabilities reduce net worth calculation

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| Multi-household / public users | Private two-person app — multi-tenancy adds complexity for zero value |
| Social expense splitting (Splitwise-style) | Not a social app; wallet transfers handle internal splits |
| Credit score checking | Requires CIBIL/Experian API partnerships and regulatory compliance |
| Real-time stock trading | Requires broker API (₹2000/month), SEBI registration |
| Robo-advisory / investment recommendations | SEBI RIA license required; significant legal liability |
| Account Aggregator (AA) framework | Requires regulatory licensing; SMS parsing achieves 80% of value at 5% complexity |
| Background SMS service | Android restrictions; on-app-open backfill is sufficient |
| Direct UPI/Google Pay integration | No public API exists |
| Crypto/forex tracking | Out of scope for India household finance |
| Multi-currency support | India-only app; INR is the only currency |
| Real-time WebSocket sync | Overkill for two users; polling is sufficient |
| OAuth/social login | Email/password sufficient for two users |
| Gamification (streaks, badges) | Finance is serious; data-driven UX preferred |
| AI-powered financial advice | Unreliable, liability risk, hosting cost |
| Export to accounting software (Tally, QuickBooks) | Personal app, not business tool; CSV/PDF export sufficient |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| AUTH-01 | Phase 1 | Pending |
| AUTH-02 | Phase 1 | Pending |
| AUTH-03 | Phase 1 | Pending |
| AUTH-04 | Phase 1 | Pending |
| AUTH-05 | Phase 1 | Pending |
| WALL-01 | Phase 1 | Pending |
| WALL-02 | Phase 1 | Pending |
| WALL-03 | Phase 2 | Pending |
| WALL-04 | Phase 2 | Pending |
| WALL-05 | Phase 2 | Pending |
| WALL-06 | Phase 3 | Pending |
| WALL-07 | Phase 2 | Pending |
| TXNS-01 | Phase 2 | Pending |
| TXNS-02 | Phase 3 | Pending |
| TXNS-03 | Phase 3 | Pending |
| TXNS-04 | Phase 3 | Pending |
| TXNS-05 | Phase 2 | Pending |
| BUDG-01 | Phase 5 | Pending |
| BUDG-02 | Phase 5 | Pending |
| BUDG-03 | Phase 5 | Pending |
| BUDG-04 | Phase 5 | Pending |
| SHOP-01 | Phase 6 | Pending |
| SHOP-02 | Phase 6 | Pending |
| SHOP-03 | Phase 6 | Pending |
| SHOP-04 | Phase 6 | Pending |
| SHOP-05 | Phase 6 | Pending |
| INVS-01 | Phase 7 | Pending |
| INVS-02 | Phase 7 | Pending |
| INVS-03 | Phase 7 | Pending |
| INVS-04 | Phase 7 | Pending |
| INVS-05 | Phase 7 | Pending |
| INVS-06 | Phase 7 | Pending |
| INVS-07 | Phase 7 | Pending |
| INVS-08 | Phase 7 | Pending |
| INVS-09 | Phase 7 | Pending |
| INVS-10 | Phase 7 | Pending |
| DOCS-01 | Phase 8 | Pending |
| DOCS-02 | Phase 8 | Pending |
| DOCS-03 | Phase 8 | Pending |
| DOCS-04 | Phase 8 | Pending |
| DOCS-05 | Phase 8 | Pending |
| DOCS-06 | Phase 8 | Pending |
| SMS-01 | Phase 9 | Pending |
| SMS-02 | Phase 9 | Pending |
| SMS-03 | Phase 9 | Pending |
| SMS-04 | Phase 9 | Pending |
| SMS-05 | Phase 9 | Pending |
| ANLY-01 | Phase 11 | Pending |
| ANLY-02 | Phase 11 | Pending |
| ANLY-03 | Phase 11 | Pending |
| ANLY-04 | Phase 11 | Pending |
| ANLY-05 | Phase 11 | Pending |
| ANLY-06 | Phase 11 | Pending |
| ANLY-07 | Phase 11 | Pending |
| ANLY-08 | Phase 11 | Pending |
| GOAL-01 | Phase 12 | Pending |
| GOAL-02 | Phase 12 | Pending |
| GOAL-03 | Phase 12 | Pending |
| GOAL-04 | Phase 12 | Pending |
| DEBT-01 | Phase 10 | Pending |
| DEBT-02 | Phase 10 | Pending |
| DEBT-03 | Phase 10 | Pending |
| DEBT-04 | Phase 10 | Pending |
| DEBT-05 | Phase 10 | Pending |
| LIFE-01 | Phase 12 | Pending |
| LIFE-02 | Phase 12 | Pending |
| LIFE-03 | Phase 12 | Pending |
| LIFE-04 | Phase 12 | Pending |
| LIFE-05 | Phase 12 | Pending |
| PLAT-01 | Phase 4 | Pending |
| PLAT-02 | Phase 4 | Pending |
| PLAT-03 | Phase 4 | Pending |
| PLAT-04 | Phase 4 | Pending |
| PLAT-05 | Phase 1 | Complete |
| PLAT-06 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 75 total
- Mapped to phases: 75
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-17*
*Last updated: 2026-03-17 after roadmap creation*
