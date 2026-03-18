-- pgTAP test: Privacy Wall RLS isolation
-- Proves User A cannot see User B's private data.
-- Run with: npx supabase test db

BEGIN;
SELECT plan(10);

-- ============================================================
-- Setup: insert test data as superuser (bypasses RLS)
-- ============================================================
-- Create two test users in auth.users
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000', 'usera@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"User A"}', 'authenticated', 'authenticated', now(), now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000', 'userb@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"User B"}', 'authenticated', 'authenticated', now(), now());

-- Create household
INSERT INTO public.households (id, name, created_by)
VALUES ('11111111-1111-1111-1111-111111111111', 'Test Household', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

-- Add both members
INSERT INTO public.household_members (household_id, user_id, role) VALUES
  ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner'),
  ('11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'member');

-- Create 3 wallets
INSERT INTO public.wallets (id, household_id, user_id, wallet_type, name) VALUES
  ('aaaa1111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'private', 'User A Private'),
  ('bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '11111111-1111-1111-1111-111111111111', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'private', 'User B Private'),
  ('cccc1111-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', NULL, 'shared', 'Shared Wallet');

-- Create categories on each wallet
INSERT INTO public.wallet_categories (wallet_id, name, sort_order) VALUES
  ('aaaa1111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Food', 0),
  ('bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'Food', 0),
  ('cccc1111-cccc-cccc-cccc-cccccccccccc', 'Food', 0);

-- ============================================================
-- Tests as User A
-- ============================================================
SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claims = '{"sub": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "role": "authenticated"}';

-- Test 1: User A can see own private wallet
SELECT is(
  (SELECT count(*)::integer FROM public.wallets WHERE id = 'aaaa1111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1,
  'User A can see own private wallet'
);

-- Test 2: User A can see shared wallet
SELECT is(
  (SELECT count(*)::integer FROM public.wallets WHERE id = 'cccc1111-cccc-cccc-cccc-cccccccccccc'),
  1,
  'User A can see shared wallet'
);

-- Test 3: User A CANNOT see User B's private wallet
SELECT is(
  (SELECT count(*)::integer FROM public.wallets WHERE id = 'bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'User A CANNOT see User B private wallet'
);

-- Test 4: User A sees exactly 2 wallets (own private + shared)
SELECT is(
  (SELECT count(*)::integer FROM public.wallets),
  2,
  'User A sees exactly 2 wallets'
);

-- Test 5: User A CANNOT see User B's private categories
SELECT is(
  (SELECT count(*)::integer FROM public.wallet_categories WHERE wallet_id = 'bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  0,
  'User A CANNOT see User B private categories'
);

-- ============================================================
-- Tests as User B (symmetric)
-- ============================================================
RESET role;
SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claims = '{"sub": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "role": "authenticated"}';

-- Test 6: User B can see own private wallet
SELECT is(
  (SELECT count(*)::integer FROM public.wallets WHERE id = 'bbbb1111-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  1,
  'User B can see own private wallet'
);

-- Test 7: User B can see shared wallet
SELECT is(
  (SELECT count(*)::integer FROM public.wallets WHERE id = 'cccc1111-cccc-cccc-cccc-cccccccccccc'),
  1,
  'User B can see shared wallet'
);

-- Test 8: User B CANNOT see User A's private wallet
SELECT is(
  (SELECT count(*)::integer FROM public.wallets WHERE id = 'aaaa1111-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0,
  'User B CANNOT see User A private wallet'
);

-- ============================================================
-- Structural tests (run as superuser)
-- ============================================================
RESET role;

-- Test 9: All public tables have RLS enabled
SELECT is(
  (SELECT count(*)::integer
   FROM pg_tables
   WHERE schemaname = 'public'
     AND NOT rowsecurity),
  0,
  'All public tables have RLS enabled'
);

-- Test 10: All RLS-enabled tables have at least one policy
SELECT is(
  (SELECT count(*)::integer
   FROM pg_tables t
   WHERE t.schemaname = 'public'
     AND t.rowsecurity = true
     AND NOT EXISTS (
       SELECT 1 FROM pg_policies p
       WHERE p.schemaname = t.schemaname AND p.tablename = t.tablename
     )),
  0,
  'All RLS-enabled tables have at least one policy'
);

SELECT * FROM finish();
ROLLBACK;
