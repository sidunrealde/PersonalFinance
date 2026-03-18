-- Migration: RLS Policies
-- Enforces the Privacy Wall: private wallet data NEVER visible to other members.
-- Uses (SELECT auth.uid()) for per-statement caching of user ID.
-- Uses ANY(private.visible_wallet_ids()) for wallet-scoped checks.

-- ============================================================
-- Revoke all from anon role (defense-in-depth)
-- ============================================================
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;

-- ============================================================
-- Enable RLS on all public tables that don't already have it
-- (Migration 00 and 01 tables were created before the event trigger)
-- ============================================================
DO $$
DECLARE
  tbl RECORD;
BEGIN
  FOR tbl IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND NOT rowsecurity
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', tbl.tablename);
  END LOOP;
END $$;

-- ============================================================
-- profiles: user sees own profile only
-- ============================================================
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = id)
  WITH CHECK ((SELECT auth.uid()) = id);

-- ============================================================
-- households
-- ============================================================
CREATE POLICY "Users see own household"
  ON public.households FOR SELECT TO authenticated
  USING (id = (SELECT private.user_household_id()));

CREATE POLICY "Users can create household"
  ON public.households FOR INSERT TO authenticated
  WITH CHECK (created_by = (SELECT auth.uid()));

CREATE POLICY "Users can update own household"
  ON public.households FOR UPDATE TO authenticated
  USING (id = (SELECT private.user_household_id()));

-- ============================================================
-- household_members
-- ============================================================
CREATE POLICY "Users see own household members"
  ON public.household_members FOR SELECT TO authenticated
  USING (household_id = (SELECT private.user_household_id()));

CREATE POLICY "Users can insert to own household"
  ON public.household_members FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR household_id = (SELECT private.user_household_id())
  );

-- ============================================================
-- household_invites
-- ============================================================
CREATE POLICY "Users manage own household invites"
  ON public.household_invites FOR ALL TO authenticated
  USING (household_id = (SELECT private.user_household_id()))
  WITH CHECK (household_id = (SELECT private.user_household_id()));

-- ============================================================
-- wallets
-- ============================================================
CREATE POLICY "Users see visible wallets"
  ON public.wallets FOR SELECT TO authenticated
  USING (id = ANY(private.visible_wallet_ids()));

CREATE POLICY "Users can insert wallets in own household"
  ON public.wallets FOR INSERT TO authenticated
  WITH CHECK (household_id = (SELECT private.user_household_id()));

CREATE POLICY "Users can update visible wallets"
  ON public.wallets FOR UPDATE TO authenticated
  USING (id = ANY(private.visible_wallet_ids()));

-- ============================================================
-- wallet_categories
-- ============================================================
CREATE POLICY "Users see categories for visible wallets"
  ON public.wallet_categories FOR SELECT TO authenticated
  USING (wallet_id = ANY(private.visible_wallet_ids()));

CREATE POLICY "Users manage categories for visible wallets"
  ON public.wallet_categories FOR INSERT TO authenticated
  WITH CHECK (wallet_id = ANY(private.visible_wallet_ids()));

CREATE POLICY "Users update categories for visible wallets"
  ON public.wallet_categories FOR UPDATE TO authenticated
  USING (wallet_id = ANY(private.visible_wallet_ids()))
  WITH CHECK (wallet_id = ANY(private.visible_wallet_ids()));

CREATE POLICY "Users delete categories for visible wallets"
  ON public.wallet_categories FOR DELETE TO authenticated
  USING (wallet_id = ANY(private.visible_wallet_ids()));

-- ============================================================
-- Wallet-scoped tables (all use visible_wallet_ids)
-- ============================================================
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'transactions', 'transaction_presets', 'budgets',
    'recurring_transactions', 'shopping_lists',
    'investment_holdings', 'documents', 'debt_instruments',
    'financial_goals', 'subscriptions'
  ]
  LOOP
    EXECUTE format(
      'CREATE POLICY "Users access %1$s for visible wallets" ON public.%1$I FOR ALL TO authenticated USING (wallet_id = ANY(private.visible_wallet_ids())) WITH CHECK (wallet_id = ANY(private.visible_wallet_ids()))',
      tbl
    );
  END LOOP;
END $$;

-- ============================================================
-- User-scoped tables (no wallet_id, uses user_id)
-- ============================================================
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'sms_rules', 'sms_merchant_mappings', 'notification_preferences'
  ]
  LOOP
    EXECUTE format(
      'CREATE POLICY "Users access own %1$s" ON public.%1$I FOR ALL TO authenticated USING (user_id = (SELECT auth.uid())) WITH CHECK (user_id = (SELECT auth.uid()))',
      tbl
    );
  END LOOP;
END $$;

-- ============================================================
-- Household-scoped tables
-- ============================================================
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'task_lists', 'calendar_events', 'important_dates'
  ]
  LOOP
    EXECUTE format(
      'CREATE POLICY "Users access %1$s in own household" ON public.%1$I FOR ALL TO authenticated USING (household_id = (SELECT private.user_household_id())) WITH CHECK (household_id = (SELECT private.user_household_id()))',
      tbl
    );
  END LOOP;
END $$;

-- ============================================================
-- Child tables (via parent FK)
-- ============================================================
CREATE POLICY "Users access items via list"
  ON public.shopping_list_items FOR ALL TO authenticated
  USING (
    list_id IN (
      SELECT id FROM public.shopping_lists
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  )
  WITH CHECK (
    list_id IN (
      SELECT id FROM public.shopping_lists
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  );

CREATE POLICY "Users access tasks via list"
  ON public.tasks FOR ALL TO authenticated
  USING (
    list_id IN (
      SELECT id FROM public.task_lists
      WHERE household_id = (SELECT private.user_household_id())
    )
  )
  WITH CHECK (
    list_id IN (
      SELECT id FROM public.task_lists
      WHERE household_id = (SELECT private.user_household_id())
    )
  );

CREATE POLICY "Users access investment txns via holding"
  ON public.investment_transactions FOR ALL TO authenticated
  USING (
    holding_id IN (
      SELECT id FROM public.investment_holdings
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  )
  WITH CHECK (
    holding_id IN (
      SELECT id FROM public.investment_holdings
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  );

CREATE POLICY "Users access debt payments via instrument"
  ON public.debt_payments FOR ALL TO authenticated
  USING (
    debt_instrument_id IN (
      SELECT id FROM public.debt_instruments
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  )
  WITH CHECK (
    debt_instrument_id IN (
      SELECT id FROM public.debt_instruments
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  );

CREATE POLICY "Users access goal contributions via goal"
  ON public.goal_contributions FOR ALL TO authenticated
  USING (
    goal_id IN (
      SELECT id FROM public.financial_goals
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  )
  WITH CHECK (
    goal_id IN (
      SELECT id FROM public.financial_goals
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  );

CREATE POLICY "Users access SIP schedules via holding"
  ON public.sip_schedules FOR ALL TO authenticated
  USING (
    holding_id IN (
      SELECT id FROM public.investment_holdings
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  )
  WITH CHECK (
    holding_id IN (
      SELECT id FROM public.investment_holdings
      WHERE wallet_id = ANY(private.visible_wallet_ids())
    )
  );

-- ============================================================
-- Public data (market NAV/prices — read-only for authenticated)
-- ============================================================
CREATE POLICY "Market data is public"
  ON public.nav_history FOR SELECT TO authenticated
  USING (true);

CREATE POLICY "Price data is public"
  ON public.price_history FOR SELECT TO authenticated
  USING (true);

-- ============================================================
-- sync_log: user's own sync records
-- ============================================================
CREATE POLICY "Users see own sync log"
  ON public.sync_log FOR ALL TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));
