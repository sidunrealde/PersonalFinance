# Feature Landscape

**Domain:** Household financial management + life organizer (two-person, India-only)
**Researched:** 2026-03-17
**Competitors Surveyed:** YNAB, Splitwise, Money Manager, Walnut (Axio), ET Money, Groww, CRED Money, Fi Money, Kuvera, Google Tasks, Todoist, Any.do, Google Keep

---

## Table Stakes

Features users expect from a personal/household finance app. Missing = product feels incomplete or users leave.

### Core Financial Management

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Transaction logging (income + expense) | Fundamental — every finance app does this | Low | Quick-add form with amount, category, date, note |
| Category management (customizable) | Users' spending doesn't fit default categories | Low | Per-wallet categories as specified in PROJECT.md |
| Budget tracking per category | YNAB, Money Manager, Walnut all have this — baseline expectation | Medium | Monthly budgets with rollover option, progress bars |
| Budget alerts (approaching/exceeding limits) | Without alerts, budgets are passive and useless | Low | Push notification + in-app badge at 80% and 100% thresholds |
| Recurring transactions | Rent, EMIs, subscriptions — users shouldn't manually re-enter monthly | Medium | Configurable frequency (daily/weekly/monthly/yearly), auto-create on due date |
| Transaction search & filter | Users need to find specific transactions quickly | Low | Filter by date range, category, wallet, amount range, keyword |
| Monthly/weekly/yearly summaries | Basic reporting — "how much did I spend this month?" | Medium | Category-wise breakdown, income vs expense, net savings |
| Category-wise spending charts | Visual pie/bar charts are expected (every competitor has them) | Medium | Pie chart for category split, bar chart for trends over time |
| Date range analytics | Users compare spending across time periods | Medium | Custom date range picker, month-over-month comparison |
| Multi-account/wallet support | Users have multiple bank accounts, cash, credit cards | Medium | At minimum: shared wallet + private wallets as defined in PROJECT.md |
| Data backup & restore | Users fear losing financial data | Medium | Local backup (exportable) + cloud backup; both as specified |
| Offline functionality (full) | Indian connectivity is unreliable; specified as non-negotiable | High | Full CRUD offline, queue changes, sync on reconnect |
| Cross-platform sync | Users switch between phone and laptop | High | Near real-time polling as specified; last-write-wins |
| Basic notifications | Budget alerts, recurring reminders, sync status | Medium | Push notifications on Android, in-app on web |
| INR currency with Indian number formatting | India-only app — ₹ symbol, lakhs/crores formatting | Low | ₹1,23,456.78 format throughout |

### Authentication & Security

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Email/password authentication | Basic auth — every app has it | Low | As specified in PROJECT.md (no OAuth needed) |
| Household invite/join flow | Two-person household setup must be seamless | Low | Invite link or code to join existing household |
| Session management | Users expect to stay logged in but be able to logout | Low | JWT/refresh token pattern |
| Data encryption at rest and in transit | Financial data — security is table stakes (CRED, Fi Money all emphasize this) | Medium | TLS for transit, encrypted DB fields for sensitive data |

---

## Differentiators

Features that set this product apart. Not universally expected, but provide competitive advantage.

### Privacy Wall Architecture (UNIQUE — no competitor has this)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Shared + private wallets with strict data isolation | **Core value prop.** No household finance app enforces mathematical privacy between partners. Splitwise shows everything; YNAB is single-user; couples apps assume full transparency | Very High | Row-level security at DB, enforced at API, verified at UI. Private wallet data NEVER leaks |
| All-direction wallet transfers (shared↔private, private↔private) | Flexible fund movement while maintaining audit trails per wallet | High | Transfer creates paired ledger entries (outgoing in source, incoming in destination) |
| Split transactions across wallets | "Dinner was ₹2000 — ₹1500 shared, ₹500 personal" — real-world pattern no app handles well | High | Single transaction UI creates two linked entries in different wallets |
| Dual view (unified feed + separate dashboards) | See everything you're allowed to see, or focus on one wallet | Medium | Shared dashboard shows shared transactions; private shows only yours; unified combines both |
| Per-wallet customizable categories | Shared expenses have different categories than personal | Low | Category belongs to wallet, not global |
| Documents follow wallet privacy rules | Receipts for personal purchases should be private | Medium | Document visibility inherited from parent wallet |

### SMS & Auto-Capture (India-specific advantage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| SMS parsing for bank/UPI transactions | **Massive India advantage.** Indian banks send SMS for every UPI/NEFT/IMPS transaction. Auto-capture eliminates manual entry — the #1 reason users abandon finance apps | Very High | Parse diverse Indian bank SMS formats (HDFC, SBI, ICICI, Axis, etc.), extract amount, merchant, reference number, date |
| On-app-open SMS backfill | Zero missed transactions even without background service | High | Scan all SMS since last processed timestamp on every app open |
| Transaction reference number deduplication | Prevents double-entry when same transaction appears in multiple SMSs or manual + SMS | Medium | Unique reference number matching from SMS content |
| Smart rules for auto-categorizing merchants | "Swiggy" → Food, "BigBasket" → Groceries — learns over time | High | Rule engine: known merchants auto-categorize, unknown create drafts for user review |
| Draft transactions for unknown merchants | Don't force-categorize unknowns — let user decide and learn | Medium | SMS creates uncategorized draft; user categorizes; system learns merchant→category mapping |

### Shopping Lists → Budget Integration (unique workflow)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multiple named shopping lists | "Hardware store", "Groceries", "Furniture" — daily household tool | Low | CRUD for lists with items |
| Per-list wallet linking | Each list deducts from its assigned wallet (shared or private) | Medium | List↔wallet FK; determines which budget gets hit |
| Auto-deduct on purchase (check-off creates transaction) | **Unique.** No competitor links shopping lists to budget deductions. Eliminates "bought it, forgot to log it" | High | Marking item as purchased auto-creates expense transaction in linked wallet |
| Estimated vs actual cost comparison | "We budgeted ₹5000 for hardware, spent ₹7200" — shopping accountability | Medium | Per-item estimated cost at list creation; actual cost on purchase; list-level comparison view |
| List-level budget impact preview | Before shopping, see "this list will use 40% of remaining monthly grocery budget" | Medium | Sum estimated costs against remaining category budget |

### Investment & Wealth Tracking (deep coverage)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Mutual fund tracking with auto NAV fetch | ET Money, Groww, Kuvera all do this — but none within a privacy-wall household context | High | Daily NAV from mfapi.in (free); store holdings as units × NAV |
| Stock tracking with auto price fetch | NSE/BSE free APIs for Indian stocks; track holdings, gains/losses | High | Daily price fetch; store as shares × price; handle stock splits |
| SIP tracking with auto-debit date calendar | Know when SIPs will hit; reminders before debit date | Medium | SIP amount, frequency, debit date; calendar view of upcoming SIPs |
| Full portfolio view per wallet | MFs + stocks in one view, per-fund/stock breakdown | High | Aggregate holdings, current value, invested value, gains/losses per fund/stock and total |
| XIRR calculation for investments | True time-weighted returns — CAGR is misleading for SIPs with irregular cash flows | High | Calculate XIRR per fund, per wallet, and portfolio-level; show absolute and annualized returns |
| Historical portfolio value charts | "How has my portfolio grown over 6 months?" | High | Plot portfolio NAV over time; requires storing daily snapshots or computing from transaction history |
| Investment gains/losses breakdown | Realized vs unrealized gains; per-fund attribution | Medium | Track sell transactions; compute realized gains; show unrealized from current holdings |
| LTCG / STCG tax implications | India-specific: different tax rates for short-term vs long-term capital gains on equity vs debt funds | Medium | Flag holdings crossing 1-year (equity) or 3-year (debt) thresholds; estimate tax liability |
| SIP step-up tracking | Many Indian investors increase SIP amounts annually | Low | Record SIP amount changes over time; project future investments |
| Dividend/payout tracking | Track dividend reinvestment or payout from MFs/stocks | Medium | Record dividend events; impact on cost basis and returns |
| Rebalancing alerts | "Your equity allocation is 75% — target was 60%" | Medium | Set target asset allocation %; alert when drift exceeds threshold |
| Investment privacy (shared + private portfolios) | Track household joint investments AND personal investments with full privacy | Medium | Investments belong to wallets; privacy rules cascade naturally |

### Financial Goals

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Shared financial goals | "Save ₹5L for house setup" — both partners contribute and track | Medium | Goal linked to shared wallet; visual progress bar; contribution history |
| Private financial goals | "Save ₹2L for my bike" — invisible to partner | Medium | Goal linked to private wallet; same UX, private visibility |
| Goal-linked savings tracking | Auto-track contributions toward goals from transactions tagged to the goal | High | Tag transactions as goal contributions; auto-update goal progress |
| Goal timeline projections | "At current savings rate, you'll reach this goal by August 2027" | Medium | Linear projection from contribution velocity |

### Document Vault

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Transaction-linked receipts | Attach photo of bill to the expense entry | Medium | Image/PDF upload linked to transaction ID |
| Standalone documents (manuals, warranties) | Store appliance manual, warranty card — not tied to specific transaction | Medium | Independent document entries with metadata (name, category, expiry) |
| Image + PDF support | Photos of receipts + PDF warranty documents | Medium | Upload, compress, store; 5MB limit per file as specified |
| Warranty expiry tracking & alerts | "Your AC warranty expires in 30 days" | Low | Date field on document; notification before expiry |
| Document search by name/category | Find "washing machine manual" quickly | Low | Text search across document metadata |

### Life Organizer (beyond finance)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Household task lists (chores) | "Clean AC filters", "Pay electricity bill" — unified household management | Medium | Assignable to either person; shared visibility; completion tracking |
| Recurring tasks/reminders | Weekly cleaning, monthly maintenance — shouldn't need re-creation | Medium | Configurable recurrence (daily/weekly/monthly/custom); auto-create next instance on completion |
| Bill reminders & due dates | Electricity, internet, insurance premiums — calendar of upcoming bills | Medium | Integrate with recurring transactions; remind 3 days and 1 day before due date |
| Quick notes / household memo | "Plumber's number: 98765...", "WiFi password: ..." — shared household info | Low | Simple shared notepad; searchable; supports pinning important notes |
| Unified calendar view | **The household command center.** One view showing: SIP debits, bill dues, task deadlines, warranty expiries, events, paydays — Todoist/Google Calendar-level integration in a household context | High | Aggregate events from recurring transactions, SIPs, tasks, document expiries, custom events into month/week/day calendar |
| Calendar event creation | Add arbitrary household events: "Parents visiting Mar 25-28", "Car insurance renewal Apr 15" | Low | Title, date/range, notes, optional financial impact estimate, optional reminder |
| Calendar color-coding by type | Visually distinguish financial events (red), tasks (blue), life events (green), reminders (yellow) | Low | Automatic based on event source; configurable per user preference |
| Calendar sharing between partners | Both partners see all shared events; private events optionally visible | Medium | Shared events always visible; private events have a "show on partner's calendar" toggle without exposing financial details |
| Household inventory | Track major purchases: "Samsung AC, bought 2024-01-15, warranty until 2026-01-15" | Medium | Item name, purchase date, cost, warranty expiry, linked document, linked transaction |
| Maintenance schedule tracking | "AC service every 6 months, last done 2025-09-15" — never miss preventive maintenance | Medium | Linked to household inventory; recurring reminders; track service cost history |
| Subscription tracker | "Netflix ₹649/month, Spotify ₹119/month, gym ₹2500/month" — know what you're paying for | Medium | Auto-detect from recurring transactions; total monthly subscription cost; cancel/keep review view |
| Important dates tracker | Birthdays, anniversaries, renewal dates — household-level memory | Low | Annual recurring dates; optional budget allocation for gifts/celebrations |
| Upcoming week / today summary | Dashboard widget: "Today: ₹3000 SIP debit, groceries task due. This week: electricity bill due Thu, warranty expiring Sat" | Medium | Aggregated from all data sources; push notification for daily morning summary |
| Seasonal/annual planning | "Diwali shopping budget", "Summer AC maintenance", "Tax filing season" — plan ahead for predictable household events | Medium | Template-based seasonal events; auto-create from previous year; linked budget allocation |
| Emergency contacts & info | "Doctor: Dr. Sharma 98765...", "Electrician: Raju 87654...", "Gas agency: HP, consumer 12345" | Low | Categorized contact list; quick-dial integration on Android |
| Household document checklist | "Passport: valid until 2028", "Aadhaar: linked to bank", "PAN: filed ITR" — track document statuses | Medium | Checklist of important household documents with expiry dates; reminder for renewals |

### Analytics & Insights (deep)

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Spending trends over time | "Your food spending increased 20% this quarter" — Fi Money and CRED Money do this | Medium | Month-over-month, quarter-over-quarter trend lines |
| Category-wise budget vs actual | "Groceries: budgeted ₹8000, spent ₹11,200" — YNAB's core insight | Medium | Side-by-side or stacked bar chart per category |
| Shared vs personal spending ratio | Unique to household app — "60% of your expenses are shared" | Low | Aggregate by wallet type |
| Merchant-level spending analysis | "You spent ₹4,500 at Swiggy this month" — powered by SMS auto-capture data | Medium | Group transactions by merchant; rank by spend |
| Net worth tracking | CRED Money, Fi Money feature this prominently — bank balance + investments - liabilities | High | Sum of all wallet balances + portfolio current value |
| Income vs expense cash flow | Monthly net cash flow visualization | Medium | Income total minus expense total per month; trend line |
| Year-end financial summary | "2025: earned ₹X, spent ₹Y, saved ₹Z, portfolio grew ₹W" | Medium | Annual aggregation of all financial data |

---

## Anti-Features

Features to explicitly NOT build. These either violate the app's philosophy, create regulatory burden, or add complexity without proportional value.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Multi-household / public user support | Private two-person app — multi-tenancy adds enormous complexity for zero value | Hardcode for single household of two users |
| Social expense splitting (Splitwise-style) | This is NOT a social app; no friend groups, no IOUs with external people | Wallet transfers handle internal splits; external debts are out of scope |
| Credit score checking | Requires API partnerships (CIBIL, Experian), regulatory compliance, offers no unique value | Link to external services if users want this |
| Loan/insurance/credit card marketplace | Revenue-driven feature for fintech apps (ET Money, Fi Money); irrelevant for personal tool | Personal app doesn't need monetization features |
| Real-time stock trading / order execution | Requires broker API (₹2000/month Kite Connect), SEBI registration, massive regulatory overhead | Track holdings only; trades are logged manually or via SMS capture |
| Robo-advisory / investment recommendations | SEBI RIA license required; significant legal liability | Show XIRR, allocation %, rebalancing alerts — let user decide |
| Account Aggregator (AA) framework | Requires regulatory licensing, partnership with AA providers; complex integration | SMS parsing achieves 80% of auto-capture value at 5% of complexity |
| Background SMS service | Android restrictions on background services; battery drain; privacy concerns | On-app-open backfill is sufficient — zero missed transactions |
| Direct UPI/Google Pay integration | No public API exists; would require NPCI tie-up | Parse UPI transaction SMSs instead |
| Crypto/forex tracking | Out of scope for India household finance; regulatory uncertainty | Not relevant to stated use case |
| Complex multi-currency | India-only app; INR is the only currency | Hardcode INR |
| Real-time WebSocket sync | Overkill for two users; complicates hosting (free-tier constraint) | Near real-time polling every 15-30 seconds when online |
| OAuth/social login | Over-engineering auth for two users | Email + password is sufficient |
| Gamification (streaks, badges, rewards) | Finance is serious — gamification feels patronizing for a personal tool | Clean, data-driven UX instead |
| AI-powered financial advice | Unreliable, liability risk, and adds LLM hosting cost | Show data clearly; let humans make decisions |
| Export to accounting software (Tally, QuickBooks) | Personal app, not a business tool | CSV/PDF export for personal records is sufficient |
| Shared expense settlement (who owes whom) | Unlike Splitwise, this app has shared wallet — no debts between household members | Shared wallet is the settlement mechanism; no IOUs needed |

---

## Feature Dependencies

```
Authentication & Household Setup
└── Wallet System (shared + private)
    ├── Transaction Management
    │   ├── Category Management
    │   ├── Budget Tracking → Budget Alerts
    │   ├── Recurring Transactions → Bill Reminders
    │   ├── SMS Parsing → Auto-Categorization → Merchant Learning
    │   │                                    → Draft Transactions
    │   └── Transaction Search & Filter
    ├── Shopping Lists
    │   ├── Per-list Wallet Linking
    │   └── Auto-Deduct on Purchase (depends on Transaction Management)
    ├── Investment Tracking
    │   ├── MF Tracking → NAV Fetch → XIRR Calc → Portfolio Charts
    │   ├── Stock Tracking → Price Fetch → Gains/Losses
    │   ├── SIP Tracking → SIP Calendar → Step-up Tracking
    │   └── Tax Implications (depends on holding period calc)
    ├── Financial Goals
    │   └── Goal-linked Savings (depends on Transaction tagging)
    ├── Document Vault
    │   ├── Transaction-linked Receipts (depends on Transaction Management)
    │   ├── Standalone Documents → Warranty Expiry Alerts
    │   └── Household Inventory (depends on Standalone Documents)
    ├── Analytics & Reports
    │   ├── Spending Charts (depends on Transaction data)
    │   ├── Budget vs Actual (depends on Budget Tracking)
    │   ├── Merchant Analysis (depends on SMS Auto-Categorization)
    │   ├── Net Worth (depends on Wallets + Investments)
    │   └── Year-end Summary (depends on all financial data)
    └── Life Organizer
        ├── Task Lists → Recurring Tasks
        ├── Quick Notes (independent)
        ├── Important Dates Tracker (independent)
        ├── Emergency Contacts & Info (independent)
        ├── Subscription Tracker (depends on Recurring Transactions detection)
        ├── Calendar View (aggregates from Recurring Txns, SIPs, Tasks, Warranties, Events, Dates)
        │   ├── Calendar Event Creation (independent)
        │   ├── Calendar Sharing (depends on Privacy Wall visibility rules)
        │   └── Today/Week Summary Widget (depends on Calendar aggregation)
        ├── Seasonal/Annual Planning (depends on Calendar + Budget system)
        ├── Household Document Checklist (depends on Document Vault)
        ├── Household Inventory (depends on Document Vault)
        └── Maintenance Schedules (depends on Household Inventory)

Cross-Platform Sync (depends on all data models being sync-ready)
Offline-First (shapes all data layer decisions — must be foundational)
Privacy Wall RLS (enforced at every layer touching wallet data)
```

### Critical Path Dependencies

1. **Privacy Wall must be Phase 1** — every feature inherits wallet visibility rules; retrofitting is architectural rewrite
2. **Offline-first must be foundational** — local-first DB design shapes every subsequent feature; adding offline later is extremely painful
3. **Transaction management before everything** — budgets, analytics, shopping auto-deduct, and SMS parsing all depend on transaction infrastructure
4. **SMS parsing before analytics** — auto-captured data makes analytics valuable; without it, manual-only data is too sparse
5. **Investment tracking is independent** — can be built in parallel with shopping/life organizer after core transaction infrastructure exists

---

## MVP Recommendation

### Must Ship (v1.0 — Core Financial + Privacy Wall)

1. **Privacy Wall architecture** (shared + private wallets with strict isolation) — *the reason this app exists*
2. **Transaction management** (CRUD, categories, recurring) — *foundation for everything*
3. **Budget tracking with alerts** — *primary daily use case*
4. **SMS auto-capture with smart categorization** — *the feature that prevents abandonment (no manual entry fatigue)*
5. **Shopping lists with auto-deduct** — *daily household workflow, unique integration*
6. **Basic analytics** (category charts, monthly summary, budget vs actual) — *necessary feedback loop*
7. **Offline-first with sync** — *non-negotiable per constraints*
8. **Cross-platform (Android + Web)** — *non-negotiable per constraints*

### Should Ship (v1.1 — Wealth + Documents)

9. **Investment tracking** (MF + stocks + SIP with auto NAV/price fetch)
10. **XIRR and portfolio analytics**
11. **Financial goals** (shared + private)
12. **Document vault** (receipts + standalone docs)
13. **Wallet transfers** (all directions)
14. **Split transactions across wallets**

### Nice to Have (v2.0 — Life Organizer + Deep Analytics)

15. **Full life organizer** (tasks, recurring tasks, household inventory, maintenance schedules)
16. **Unified calendar view** (financial events + life events + tasks + custom events)
17. **Calendar event creation & sharing** between partners
18. **Today/week summary widget** (morning briefing of what's due)
19. **Subscription tracker** (auto-detect from recurring transactions)
20. **Seasonal/annual planning** (Diwali budgets, tax season, maintenance cycles)
21. **Important dates tracker** (birthdays, anniversaries, renewals)
22. **Emergency contacts & household info**
23. **Household document checklist** (passport expiry, Aadhaar status, etc.)
24. **Deep analytics** (spending trends, merchant analysis, net worth, year-end summary)
25. **Tax implications** (LTCG/STCG flagging)
26. **Rebalancing alerts**
27. **Quick notes / household memo**

---

## Prioritization Matrix

| Feature Group | User Impact | Technical Complexity | Dependency Risk | Priority |
|---------------|------------|---------------------|-----------------|----------|
| Privacy Wall | Critical (core value) | Very High | Foundational — blocks everything | P0 |
| Offline-First Architecture | Critical (constraint) | Very High | Foundational — shapes data layer | P0 |
| Transaction Management | Critical (daily use) | Medium | Required by budgets, analytics, shopping | P0 |
| Budget Tracking + Alerts | High (daily use) | Medium | Requires transactions | P0 |
| SMS Auto-Capture | High (prevents abandonment) | Very High | Requires transactions; India-specific SMS parsing | P0 |
| Shopping Lists + Auto-Deduct | High (daily household use) | Medium-High | Requires transactions + wallets | P0 |
| Recurring Transactions | High (convenience) | Medium | Requires transactions | P0 |
| Basic Analytics | Medium-High (feedback loop) | Medium | Requires transaction data | P1 |
| Investment Tracking (MF+Stocks) | High (stated core feature) | High | Independent after wallet system | P1 |
| XIRR + Portfolio Analytics | Medium-High (investor users) | High | Requires investment holdings + transaction history | P1 |
| Financial Goals | Medium (motivational) | Medium | Requires wallets | P1 |
| Document Vault | Medium (utility) | Medium | Independent after wallet system | P1 |
| Wallet Transfers | Medium (flexibility) | Medium-High | Requires wallets + ledger logic | P1 |
| Split Transactions | Medium (real-world pattern) | High | Requires multi-wallet transaction logic | P1 |
| Life Organizer (tasks, chores) | Medium (household utility) | Medium | Independent module | P2 |
| Unified Calendar View | High (command center) | High | Aggregates from many sources | P2 |
| Calendar Events & Sharing | Medium-High (planning) | Medium | Requires calendar foundation | P2 |
| Today/Week Summary Widget | Medium-High (daily use) | Medium | Requires calendar aggregation | P2 |
| Subscription Tracker | Medium (cost awareness) | Medium | Requires recurring transaction detection | P2 |
| Seasonal/Annual Planning | Medium (forward planning) | Medium | Requires calendar + budgets | P2 |
| Important Dates Tracker | Low-Medium (convenience) | Low | Independent module | P2 |
| Emergency Contacts & Info | Low-Medium (utility) | Low | Independent module | P2 |
| Household Document Checklist | Low-Medium (utility) | Medium | Requires document vault | P2 |
| Deep Analytics | Medium (power user) | Medium-High | Requires rich transaction data | P2 |
| Household Inventory | Low-Medium | Medium | Depends on document vault | P2 |
| Tax Implications | Low-Medium (annual event) | Medium | Requires investment holding period tracking | P2 |
| Rebalancing Alerts | Low (power investor) | Medium | Requires portfolio allocation tracking | P2 |
| Net Worth Tracking | Medium (motivational) | Medium-High | Requires wallets + investments aggregate | P2 |

---

## Sources

- YNAB features page (ynab.com/features/) — budgeting methodology, goal tracking, reports, bank import, subscription sharing (fetched 2026-03-17)
- CRED Money (cred.club/money) — net worth tracking, MF/stocks/FD/gold aggregation, AA framework, bank-grade security (fetched 2026-03-17)
- Groww (groww.in/mutual-funds) — direct MF investment, SIP, portfolio tracking, zero commission, stock trading (fetched 2026-03-17)
- ET Money (etmoney.com) — MF investment, SIP calculator, tax saving, NPS, FDs, loan against MF (fetched 2026-03-17)
- Kuvera (kuvera.in) — direct MF, goal planning, fund comparison, portfolio import, XIRR (fetched 2026-03-17)
- Fi Money (fi.money/features) — spend insights, net worth, MF, US stocks, savings account (fetched 2026-03-17)
- Splitwise (training data, HIGH confidence) — group expense splitting, IOUs, simplified debts, balances
- Money Manager (training data, MEDIUM confidence) — expense tracking, categories, reports, budgets
- Walnut/Axio (training data, MEDIUM confidence) — SMS parsing for Indian bank transactions, auto-categorization, spending insights
- YNAB methodology (training data, HIGH confidence) — envelope budgeting, zero-based budgeting, rule-based categories
- Indian banking SMS format patterns (training data, HIGH confidence) — HDFC, SBI, ICICI, Axis, Kotak all send structured SMS with amount, ref number, balance
- mfapi.in (training data, HIGH confidence) — free mutual fund NAV API for Indian MFs
- NSE/BSE free market data (training data, MEDIUM confidence) — stock price APIs available for Indian equities
