-- Migration: Helper Functions & Triggers
-- Server-updated-at trigger, auto-RLS event trigger, privacy helper functions,
-- auth trigger, and accept_invite RPC.

-- ============================================================
-- Auto-update server_updated_at on every write
-- ============================================================
CREATE OR REPLACE FUNCTION public.set_server_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.server_updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply to all existing tables with server_updated_at column
DO $$
DECLARE
  tbl RECORD;
BEGIN
  FOR tbl IN
    SELECT table_name
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND column_name = 'server_updated_at'
  LOOP
    EXECUTE format(
      'CREATE TRIGGER set_server_updated_at BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_server_updated_at()',
      tbl.table_name
    );
  END LOOP;
END $$;

-- ============================================================
-- Auto-enable RLS on any new table in public schema
-- ============================================================
CREATE OR REPLACE FUNCTION rls_auto_enable()
RETURNS EVENT_TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table', 'partitioned table')
  LOOP
    IF cmd.schema_name IS NOT NULL
      AND cmd.schema_name IN ('public')
      AND cmd.schema_name NOT IN ('pg_catalog', 'information_schema')
      AND cmd.schema_name NOT LIKE 'pg_toast%'
      AND cmd.schema_name NOT LIKE 'pg_temp%'
    THEN
      BEGIN
        EXECUTE format('ALTER TABLE IF EXISTS %s ENABLE ROW LEVEL SECURITY', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
    END IF;
  END LOOP;
END;
$$;

DROP EVENT TRIGGER IF EXISTS ensure_rls;
CREATE EVENT TRIGGER ensure_rls
ON ddl_command_end
WHEN TAG IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
EXECUTE FUNCTION rls_auto_enable();

-- ============================================================
-- Helper: Get visible wallet IDs for current user
-- Returns own private wallet + shared wallet in user's household
-- ============================================================
CREATE OR REPLACE FUNCTION private.visible_wallet_ids()
RETURNS uuid[]
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT COALESCE(array_agg(w.id), ARRAY[]::uuid[])
  FROM public.wallets w
  WHERE w.deleted_at IS NULL
    AND (
      -- User's own private wallet
      w.user_id = (SELECT auth.uid())
      -- Shared wallet in user's household
      OR (
        w.wallet_type = 'shared'
        AND w.household_id IN (
          SELECT hm.household_id
          FROM public.household_members hm
          WHERE hm.user_id = (SELECT auth.uid())
            AND hm.left_at IS NULL
        )
      )
    )
$$;

-- ============================================================
-- Helper: Get user's current household ID
-- ============================================================
CREATE OR REPLACE FUNCTION private.user_household_id()
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
  SELECT hm.household_id
  FROM public.household_members hm
  WHERE hm.user_id = (SELECT auth.uid())
    AND hm.left_at IS NULL
  LIMIT 1
$$;

-- ============================================================
-- Trigger: Auto-create profile on auth.users insert
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name)
  VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'display_name', ''));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- RPC: Accept household invite
-- Validates invite, adds member, creates private wallet + categories
-- ============================================================
CREATE OR REPLACE FUNCTION public.accept_invite(p_invite_token UUID)
RETURNS UUID  -- returns household_id
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invite RECORD;
  v_user_id UUID;
  v_household_id UUID;
  v_wallet_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Find valid invite
  SELECT * INTO v_invite
  FROM public.household_invites
  WHERE invite_token = p_invite_token
    AND accepted_at IS NULL
    AND revoked_at IS NULL
    AND expires_at > now();

  IF v_invite IS NULL THEN
    RAISE EXCEPTION 'Invalid or expired invite';
  END IF;

  v_household_id := v_invite.household_id;

  -- Check not already a member
  IF EXISTS (
    SELECT 1 FROM public.household_members
    WHERE household_id = v_household_id AND user_id = v_user_id AND left_at IS NULL
  ) THEN
    RAISE EXCEPTION 'Already a member of this household';
  END IF;

  -- Add member
  INSERT INTO public.household_members (household_id, user_id, role)
  VALUES (v_household_id, v_user_id, 'member');

  -- Update profile
  UPDATE public.profiles SET household_id = v_household_id WHERE id = v_user_id;

  -- Mark invite accepted
  UPDATE public.household_invites
  SET accepted_by = v_user_id, accepted_at = now()
  WHERE id = v_invite.id;

  -- Create private wallet for new member
  v_wallet_id := gen_random_uuid();
  INSERT INTO public.wallets (id, household_id, user_id, wallet_type, name)
  VALUES (v_wallet_id, v_household_id, v_user_id, 'private', 'My Wallet');

  -- Seed default categories
  INSERT INTO public.wallet_categories (wallet_id, name, sort_order)
  SELECT v_wallet_id,
         unnest(ARRAY['Food', 'Transport', 'Shopping', 'Bills', 'Health', 'Entertainment', 'Education', 'Miscellaneous']),
         generate_series(0, 7);

  RETURN v_household_id;
END;
$$;
