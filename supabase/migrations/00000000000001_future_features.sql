-- Migration: Future-feature tables
-- All tables for Phases 2-12. Created upfront so schema is complete.
-- Tables remain empty until their phase activates them.

-- ============================================================
-- recurring_transactions (Phase 5) — must be before transactions
-- ============================================================
CREATE TABLE public.recurring_transactions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id         UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  category_id       UUID,  -- FK added after wallet_categories exists in this context
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  name              TEXT NOT NULL,
  amount_paise      BIGINT NOT NULL,
  transaction_type  TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  frequency         TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'monthly', 'yearly')),
  start_date        DATE NOT NULL,
  end_date          DATE,
  next_due_date     DATE NOT NULL,
  reminder_days_before INTEGER NOT NULL DEFAULT 3,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

ALTER TABLE public.recurring_transactions
  ADD CONSTRAINT fk_recurring_category
  FOREIGN KEY (category_id) REFERENCES public.wallet_categories(id) ON DELETE SET NULL;

-- ============================================================
-- transactions (Phase 2)
-- ============================================================
CREATE TABLE public.transactions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id             UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  category_id           UUID REFERENCES public.wallet_categories(id) ON DELETE SET NULL,
  user_id               UUID NOT NULL REFERENCES auth.users(id),
  amount_paise          BIGINT NOT NULL,
  transaction_type      TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  note                  TEXT,
  transaction_date      TIMESTAMPTZ NOT NULL DEFAULT now(),
  transfer_ref          UUID,
  split_ref             UUID,
  is_recurring_instance BOOLEAN NOT NULL DEFAULT false,
  recurring_transaction_id UUID REFERENCES public.recurring_transactions(id) ON DELETE SET NULL,
  is_draft              BOOLEAN NOT NULL DEFAULT false,
  sms_ref               TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  synced_at             TIMESTAMPTZ,
  deleted_at            TIMESTAMPTZ
);

CREATE INDEX idx_txn_wallet ON public.transactions(wallet_id);
CREATE INDEX idx_txn_user ON public.transactions(user_id);
CREATE INDEX idx_txn_date ON public.transactions(transaction_date);
CREATE INDEX idx_txn_category ON public.transactions(category_id);
CREATE INDEX idx_txn_transfer ON public.transactions(transfer_ref) WHERE transfer_ref IS NOT NULL;
CREATE INDEX idx_txn_split ON public.transactions(split_ref) WHERE split_ref IS NOT NULL;
CREATE INDEX idx_txn_sms_ref ON public.transactions(sms_ref) WHERE sms_ref IS NOT NULL;

-- ============================================================
-- transaction_presets (Phase 3)
-- ============================================================
CREATE TABLE public.transaction_presets (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id         UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  category_id       UUID REFERENCES public.wallet_categories(id) ON DELETE SET NULL,
  name              TEXT NOT NULL,
  amount_paise      BIGINT NOT NULL,
  transaction_type  TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  sort_order        INTEGER NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- budgets (Phase 5)
-- ============================================================
CREATE TABLE public.budgets (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id         UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  category_id       UUID NOT NULL REFERENCES public.wallet_categories(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  month_year        TEXT NOT NULL,
  limit_paise       BIGINT NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ,
  UNIQUE (wallet_id, category_id, month_year)
);

-- ============================================================
-- shopping_lists (Phase 6)
-- ============================================================
CREATE TABLE public.shopping_lists (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id      UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  wallet_id         UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  name              TEXT NOT NULL,
  is_archived       BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- shopping_list_items (Phase 6)
-- ============================================================
CREATE TABLE public.shopping_list_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id           UUID NOT NULL REFERENCES public.shopping_lists(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  estimated_paise   BIGINT,
  actual_paise      BIGINT,
  is_purchased      BOOLEAN NOT NULL DEFAULT false,
  purchased_at      TIMESTAMPTZ,
  transaction_id    UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  sort_order        INTEGER NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- investment_holdings (Phase 7)
-- ============================================================
CREATE TABLE public.investment_holdings (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id           UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id             UUID NOT NULL REFERENCES auth.users(id),
  instrument_type     TEXT NOT NULL CHECK (instrument_type IN ('mutual_fund', 'stock')),
  instrument_name     TEXT NOT NULL,
  instrument_code     TEXT,
  units_micro         BIGINT NOT NULL DEFAULT 0,
  avg_buy_price_paise BIGINT NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at          TIMESTAMPTZ
);

-- ============================================================
-- investment_transactions (Phase 7)
-- ============================================================
CREATE TABLE public.investment_transactions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  holding_id        UUID NOT NULL REFERENCES public.investment_holdings(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  transaction_type  TEXT NOT NULL CHECK (transaction_type IN ('buy', 'sell', 'dividend', 'switch_in', 'switch_out')),
  units_micro       BIGINT NOT NULL,
  price_paise       BIGINT NOT NULL,
  amount_paise      BIGINT NOT NULL,
  transaction_date  DATE NOT NULL,
  note              TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- nav_history (Phase 7)
-- ============================================================
CREATE TABLE public.nav_history (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_code   TEXT NOT NULL,
  nav_date          DATE NOT NULL,
  nav_paise         BIGINT NOT NULL,
  fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (instrument_code, nav_date)
);

-- ============================================================
-- price_history (Phase 7)
-- ============================================================
CREATE TABLE public.price_history (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instrument_code   TEXT NOT NULL,
  price_date        DATE NOT NULL,
  close_paise       BIGINT NOT NULL,
  fetched_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (instrument_code, price_date)
);

-- ============================================================
-- sip_schedules (Phase 7)
-- ============================================================
CREATE TABLE public.sip_schedules (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  holding_id        UUID NOT NULL REFERENCES public.investment_holdings(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  amount_paise      BIGINT NOT NULL,
  frequency         TEXT NOT NULL CHECK (frequency IN ('monthly', 'weekly', 'quarterly')),
  debit_day         INTEGER NOT NULL CHECK (debit_day BETWEEN 1 AND 31),
  start_date        DATE NOT NULL,
  end_date          DATE,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- documents (Phase 8)
-- ============================================================
CREATE TABLE public.documents (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id         UUID REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  transaction_id    UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  name              TEXT NOT NULL,
  category          TEXT,
  file_path         TEXT NOT NULL,
  file_type         TEXT NOT NULL,
  file_size_bytes   INTEGER NOT NULL,
  expiry_date       DATE,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- sms_rules (Phase 9)
-- ============================================================
CREATE TABLE public.sms_rules (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  sender_pattern    TEXT NOT NULL,
  body_pattern      TEXT NOT NULL,
  bank_name         TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- sms_merchant_mappings (Phase 9)
-- ============================================================
CREATE TABLE public.sms_merchant_mappings (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  merchant_name     TEXT NOT NULL,
  category_id       UUID REFERENCES public.wallet_categories(id) ON DELETE SET NULL,
  wallet_id         UUID REFERENCES public.wallets(id) ON DELETE SET NULL,
  times_used        INTEGER NOT NULL DEFAULT 1,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, merchant_name)
);

-- ============================================================
-- debt_instruments (Phase 10)
-- ============================================================
CREATE TABLE public.debt_instruments (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id               UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id                 UUID NOT NULL REFERENCES auth.users(id),
  debt_type               TEXT NOT NULL CHECK (debt_type IN ('emi', 'loan_given', 'loan_received')),
  name                    TEXT NOT NULL,
  principal_paise         BIGINT NOT NULL,
  remaining_paise         BIGINT NOT NULL,
  interest_rate_bps       INTEGER,
  emi_paise               BIGINT,
  tenure_months           INTEGER,
  counterparty_name       TEXT,
  start_date              DATE NOT NULL,
  end_date                DATE,
  next_payment_date       DATE,
  is_active               BOOLEAN NOT NULL DEFAULT true,
  recurring_transaction_id UUID REFERENCES public.recurring_transactions(id) ON DELETE SET NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at              TIMESTAMPTZ
);

-- ============================================================
-- debt_payments (Phase 10)
-- ============================================================
CREATE TABLE public.debt_payments (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_instrument_id  UUID NOT NULL REFERENCES public.debt_instruments(id) ON DELETE CASCADE,
  transaction_id      UUID REFERENCES public.transactions(id) ON DELETE SET NULL,
  amount_paise        BIGINT NOT NULL,
  payment_date        DATE NOT NULL,
  note                TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- financial_goals (Phase 12)
-- ============================================================
CREATE TABLE public.financial_goals (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id         UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  name              TEXT NOT NULL,
  target_paise      BIGINT NOT NULL,
  current_paise     BIGINT NOT NULL DEFAULT 0,
  target_date       DATE,
  icon              TEXT,
  color             TEXT,
  is_active         BOOLEAN NOT NULL DEFAULT true,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- goal_contributions (Phase 12)
-- ============================================================
CREATE TABLE public.goal_contributions (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  goal_id           UUID NOT NULL REFERENCES public.financial_goals(id) ON DELETE CASCADE,
  amount_paise      BIGINT NOT NULL,
  contributed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  note              TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- task_lists (Phase 12)
-- ============================================================
CREATE TABLE public.task_lists (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id      UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  name              TEXT NOT NULL,
  created_by        UUID NOT NULL REFERENCES auth.users(id),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- tasks (Phase 12)
-- ============================================================
CREATE TABLE public.tasks (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  list_id           UUID NOT NULL REFERENCES public.task_lists(id) ON DELETE CASCADE,
  assigned_to       UUID REFERENCES auth.users(id),
  title             TEXT NOT NULL,
  is_completed      BOOLEAN NOT NULL DEFAULT false,
  completed_at      TIMESTAMPTZ,
  due_date          TIMESTAMPTZ,
  sort_order        INTEGER NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- calendar_events (Phase 12)
-- ============================================================
CREATE TABLE public.calendar_events (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id      UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  title             TEXT NOT NULL,
  event_type        TEXT NOT NULL CHECK (event_type IN ('custom', 'sip', 'bill', 'emi', 'warranty', 'birthday', 'anniversary', 'other')),
  event_date        DATE NOT NULL,
  is_recurring      BOOLEAN NOT NULL DEFAULT false,
  recurrence_rule   TEXT,
  related_id        UUID,
  related_table     TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at        TIMESTAMPTZ
);

-- ============================================================
-- subscriptions (Phase 12)
-- ============================================================
CREATE TABLE public.subscriptions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id               UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id                 UUID NOT NULL REFERENCES auth.users(id),
  name                    TEXT NOT NULL,
  amount_paise            BIGINT NOT NULL,
  frequency               TEXT NOT NULL CHECK (frequency IN ('monthly', 'yearly', 'quarterly')),
  renewal_date            DATE NOT NULL,
  is_active               BOOLEAN NOT NULL DEFAULT true,
  recurring_transaction_id UUID REFERENCES public.recurring_transactions(id) ON DELETE SET NULL,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at              TIMESTAMPTZ
);

-- ============================================================
-- important_dates (Phase 12)
-- ============================================================
CREATE TABLE public.important_dates (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id          UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id               UUID NOT NULL REFERENCES auth.users(id),
  title                 TEXT NOT NULL,
  date_type             TEXT NOT NULL CHECK (date_type IN ('birthday', 'anniversary', 'renewal', 'other')),
  event_date            DATE NOT NULL,
  reminder_days_before  INTEGER NOT NULL DEFAULT 7,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at            TIMESTAMPTZ
);

-- ============================================================
-- notification_preferences
-- ============================================================
CREATE TABLE public.notification_preferences (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type   TEXT NOT NULL,
  is_enabled          BOOLEAN NOT NULL DEFAULT true,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, notification_type)
);

-- ============================================================
-- sync_log
-- ============================================================
CREATE TABLE public.sync_log (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id),
  table_name        TEXT NOT NULL,
  record_id         UUID NOT NULL,
  operation         TEXT NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
  synced_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
