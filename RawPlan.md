# Product Requirements Document (PRD): Household Financial & Life Organizer

## 1. Project Overview
A comprehensive, cross-platform (Android & Web) application combining daily life organization (tasks, shopping lists) with advanced financial management (budgeting, investments, SIP tracking). 

The foundational pillar of this application is the **"Shared but Private" (The Privacy Wall)** architecture. It is designed for a household of two, providing a unified dashboard for joint expenses while maintaining strict, mathematically enforced data isolation for personal wallets.

## 2. Technology Stack & Infrastructure (Free Tier Optimized)
* **Frontend (Mobile & Web):** Flutter (Dart) for a single, responsive codebase.
* **Backend API:** Python (FastAPI) for high-performance REST APIs, background scraping, and algorithmic calculations. Hosted on **Render**.
* **Database & Authentication:** PostgreSQL via **Supabase**. Handles user auth, Row Level Security (RLS), and real-time WebSocket syncing.
* **Document Vault:** Supabase Storage for uploading receipts, appliance manuals, and warranties.
* **Version Control & CI/CD:** Git and GitHub Actions for automated testing and deployment.

---

## 3. Core Database Schema & The Privacy Wall
Role-Based Access Control (RLS) must be strictly enforced at the database level. 

* **Rule 1:** A `User` can only `SELECT`, `UPDATE`, or `DELETE` records where the `wallet_id` matches their `private_wallet_id` OR the `shared_wallet_id` linked to their `household_id`.
* **Rule 2:** Transfers from Shared to Private create two ledger entries: an outgoing expense in the Shared Ledger, and an incoming deposit in the receiving User's Private Ledger. The subsequent usage of those private funds remains invisible to the other user.

### Essential Tables (SQLAlchemy/Supabase Definitions)
* **Households:** `id` (UUID, PK), `name` (String), `created_at` (Timestamp).
* **Users:** `id` (UUID, PK), `household_id` (UUID, FK), `name` (String), `auth_token` (String).
* **Wallets:** `id` (UUID, PK), `owner_type` (Enum: 'Shared', 'Private'), `household_id` (UUID, FK, nullable), `user_id` (UUID, FK, nullable), `balance` (Decimal).
* **Categories:** `id` (UUID, PK), `name` (String), `type` (Enum: 'Income', 'Expense', 'Investment').
* **Transactions:** `id` (UUID, PK), `wallet_id` (UUID, FK), `amount` (Decimal), `category_id` (UUID, FK), `timestamp` (DateTime), `notes` (String).
* **Goals:** `id` (UUID, PK), `wallet_id` (UUID, FK), `target_amount` (Decimal), `current_amount` (Decimal), `title` (String). *(e.g., "New House Setup" mapped to Shared_Wallet; "Royal Enfield Guerrilla 450 Down Payment" mapped to Private_Wallet).*
* **ShoppingLists:** `id` (UUID, PK), `wallet_id` (UUID, FK), `title` (String).
* **ListItems:** `id` (UUID, PK), `list_id` (UUID, FK), `name` (String), `estimated_cost` (Decimal), `actual_cost` (Decimal), `is_purchased` (Boolean).
* **Investments:** `id` (UUID, PK), `wallet_id` (UUID, FK), `fund_name` (String), `units` (Decimal), `avg_nav` (Decimal), `is_sip` (Boolean), `sip_date` (Integer).

---

## 4. Phased Development Roadmap

### Phase 1: Foundation, Auth & The Privacy Wall
**Overview:** Establish the secure data flow, user authentication, and the core database logic before any UI is built. The backend must be bulletproof regarding data visibility.

* **Steps:**
    1. Initialize Supabase project and execute SQL scripts for the core schema (`Households`, `Users`, `Wallets`, `Transactions`).
    2. Configure Supabase Email/Password authentication.
    3. Write a Supabase Database Trigger: On new user signup, automatically generate a `Private_Wallet` and prompt for a `Household` invite link.
    4. Set up the Python FastAPI backend with SQLAlchemy/Supabase Client.
    5. Build core REST endpoints: `POST /transaction`, `GET /ledger/shared`, `GET /ledger/private`.
* **Tests & Validations:**
    * *DB Validation:* Write Row Level Security (RLS) policies and test directly in SQL editor to ensure User A cannot query User B's private transactions.
    * *API Tests:* Use `pytest` to verify endpoints correctly reject unauthorized wallet access (HTTP 403).

### Phase 2: UI Skeleton & Core Ledger Sync
**Overview:** Build the cross-platform Flutter frontend and establish real-time data syncing between the web dashboard and mobile devices.

* **Steps:**
    1. Initialize Flutter project with a state management solution (e.g., Riverpod).
    2. Build Auth screens (Login/Signup/Household Invite).
    3. Build the primary Navigation framework: A hard toggle between the "Shared Dashboard" and "Private Dashboard".
    4. Implement forms to add Income, Expenses, and Wallet Transfers.
    5. Integrate Supabase real-time WebSockets to update the UI instantly when a transaction occurs on another device.
* **Tests & Validations:**
    * *Frontend Validation:* Ensure UI forms block submission of negative numbers or empty mandatory fields.
    * *Integration Tests:* Run two local instances (Web and Android Emulator). Execute a transaction on Web and verify the Android UI updates without a manual refresh.

### Phase 3: The Organizer & Shopping Integrations
**Overview:** Bridge the gap between static budgets and actionable daily tasks. Introduce automated budget deductions based on completed tasks or shopping trips.

* **Steps:**
    1. Add `ShoppingLists` and `ListItems` tables/endpoints.
    2. Build the Flutter UI for collaborative lists (e.g., creating a master list for hardware, furniture, and kitchen supplies).
    3. **Core Logic Implementation:** Link lists to specific `Category_IDs`. When `is_purchased` toggles to True, fire a backend transaction that deducts the `actual_cost` from the associated Wallet and Category.
    4. Build the Document Vault UI: Allow users to upload images (receipts/manuals) to Supabase Storage and link the URL to a specific transaction.
* **Tests & Validations:**
    * *Logic Validation:* If a list item's `actual_cost` exceeds the current wallet balance, the backend must return an error and prevent the checkbox state from saving.
    * *Storage Tests:* Verify uploaded files do not exceed a 5MB payload limit to conserve free-tier storage.

### Phase 4: Wealth Manager, Goals & SIP Engine
**Overview:** Transform the app into an automated wealth-building platform with real-time portfolio tracking and algorithmic suggestions.

* **Steps:**
    1. Implement visual progress bars for Financial Goals in Flutter.
    2. Build the `Investments` API endpoints.
    3. Write a Python background task (using `FastAPI BackgroundTasks` or a simple cron job triggering an endpoint) to fetch daily Net Asset Values (NAV) via `mfapi.in`.
    4. Calculate daily portfolio valuation updates in the backend and expose them to the frontend.
    5. Build the SIP Calendar view showing upcoming auto-debit dates.
* **Tests & Validations:**
    * *Background Task Tests:* Mock the `mfapi.in` response in `pytest` to ensure the Python scraper handles network timeouts (HTTP 503) gracefully without corrupting the database.
    * *Math Validation:* Ensure fractional units of mutual funds are calculated to at least 4 decimal places.

### Phase 5: Polish, CI/CD & Final Deployment
**Overview:** Prepare the application for daily, reliable production use with automated pipelines and mobile-specific enhancements.

* **Steps:**
    1. Set up GitHub Actions: On push to `main`, run `pytest` and Flutter analyzer.
    2. If tests pass, deploy FastAPI updates automatically to Render.
    3. Build Flutter Web and deploy to a free static host (e.g., Vercel or Supabase Hosting).
    4. Implement local caching (`sqflite` or `hive`) in Flutter for offline expense logging on Android.
    5. Compile the Android release APK.
* **Tests & Validations:**
    * *Offline Sync Test:* Disconnect the Android emulator from Wi-Fi, log a transaction, reconnect to Wi-Fi, and verify the background sync pushes the payload to Supabase successfully.