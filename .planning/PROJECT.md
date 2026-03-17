# Household Financial & Life Organizer

## What This Is

A cross-platform (Android + Web) app for a two-person household that combines daily financial management with life organization tools. It provides a unified dashboard for joint expenses while enforcing strict, mathematically guaranteed data isolation between personal wallets — the "Shared but Private" architecture. The app also tracks investments (mutual funds + stocks), manages shopping lists that auto-deduct from budgets, and stores financial documents.

## Core Value

The Privacy Wall — a shared household wallet for joint expenses with strictly isolated private wallets where each person's personal finances remain completely invisible to the other, enforced at every layer of the system.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Privacy Wall with shared + private wallets (strict data isolation)
- [ ] All-direction wallet transfers (shared↔private, private↔private)
- [ ] Split transactions across wallets (partly shared, partly personal)
- [ ] Per-wallet customizable expense/income categories
- [ ] Category budgets with alerts when approaching/exceeding limits
- [ ] Auto-recurring transactions (rent, subscriptions, EMIs)
- [ ] Quick-add expense form with one-click presets for frequent expenses
- [ ] Dual view — unified feed for overview + separate shared/private dashboards
- [ ] Multiple named shopping lists (hardware, groceries, furniture) with estimated costs
- [ ] Per-list wallet linking — each list tied to shared OR a private wallet
- [ ] Auto-deduct on purchase (checking "purchased" creates a transaction)
- [ ] Estimated vs actual cost comparison for shopping lists
- [ ] Financial goals — both shared goals and private goals
- [ ] Investment tracking — mutual funds + stocks in both shared and private wallets
- [ ] SIP tracking with amounts and auto-debit dates
- [ ] Auto NAV/price fetching daily with manual override
- [ ] Full portfolio view — per-fund/stock breakdown, gains/losses, historical charts
- [ ] Document vault — transaction receipts + standalone docs (manuals, warranties)
- [ ] Documents follow wallet privacy rules (shared docs visible to both, private docs private)
- [ ] Images + PDF support for document vault
- [ ] SMS parsing for auto-capture of bank/UPI transactions (Android)
- [ ] Smart rules for auto-categorizing known merchants + drafts for unknown
- [ ] On-app-open SMS backfill — scans all SMS since last processed, zero missed transactions
- [ ] Transaction reference number deduplication (no duplicate entries from SMS)
- [ ] Deep analytics — filters, date ranges, category charts, spending comparisons
- [ ] All notifications — budget alerts, recurring reminders, SIP dates, shared wallet activity
- [ ] Offline-first — full functionality offline, sync when connected
- [ ] Near real-time sync via polling when online
- [ ] Last-write-wins conflict resolution for simplicity
- [ ] Both local + cloud backup for data safety
- [ ] Cross-platform — Android app + Web app from single codebase

### Out of Scope

- Multi-household / public user support — this is a private two-person app
- Real-time WebSocket sync — near real-time polling is sufficient
- Background SMS service — only process SMS when app is opened
- Account Aggregator (AA) framework integration — requires regulatory licensing
- Zerodha Kite Connect API — ₹2000/month, too expensive for personal use
- Direct Google Pay/UPI API integration — no public API exists
- OAuth/social login — email/password auth is sufficient

## Context

- **Users**: Two-person household (couple), both on Android, also want web access on larger screens
- **Current pain**: Managing finances via spreadsheets — manual, error-prone, no real-time visibility
- **India-specific**: UPI is the primary payment method; banks send SMS notifications with transaction reference numbers; mfapi.in provides free mutual fund NAV data; NSE/BSE free APIs available for stock prices
- **Offline reality**: Users need to log expenses while out without signal; app must work fully offline and sync when back online
- **Investment context**: Active mutual fund and stock investors; SIPs are regular; need portfolio tracking not just expense tracking
- **Shopping workflow**: Shopping lists are a daily tool — creating lists before trips, checking off items as purchased, auto-deducting from the linked wallet's budget

## Constraints

- **Budget**: Free-tier infrastructure only (no paid API subscriptions or hosting)
- **Platform**: Must work on Android + Web from a single codebase
- **Privacy**: Row-level data isolation enforced at database level — private wallet data must NEVER leak to the other user
- **Offline**: Full offline functionality is non-negotiable — not degraded mode, full functionality
- **File size**: Document uploads capped to conserve free-tier storage (5MB per file)
- **SMS**: Only parsed on app open, not via background service; must handle diverse Indian bank SMS formats

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Stack is fully flexible | User open to best-fit tech, not locked to any specific framework | — Pending |
| Privacy Wall as foundation | Everything else (features, UI, sync) builds on top of strict wallet isolation | — Pending |
| Offline-first architecture | Core requirement, not afterthought — shapes DB, sync, and data layer choices | — Pending |
| SMS parsing on app open only | Avoids Android background service restrictions; backfills from last timestamp | — Pending |
| Last-write-wins conflict resolution | Two users, low concurrency — simplicity over complexity | — Pending |
| Near real-time polling over WebSocket | Sufficient for two users; simpler architecture and hosting | — Pending |
| Free-tier only infrastructure | Personal project, no revenue — must stay within free hosting/API limits | — Pending |
| Per-list wallet linking for shopping | Each shopping list deducts from its assigned wallet (shared or private) | — Pending |
| Smart rules + drafts for SMS categorization | Known merchants auto-categorize; new ones flagged for review; learns over time | — Pending |

---
*Last updated: 2026-03-17 after initialization*
