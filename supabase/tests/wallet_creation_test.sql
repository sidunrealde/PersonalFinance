-- pgTAP test: accept_invite RPC creates wallet + categories
-- Run with: npx supabase test db

BEGIN;
SELECT plan(5);

-- ============================================================
-- Setup: create User A as household owner with shared wallet
-- ============================================================
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000', 'owner@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Owner"}', 'authenticated', 'authenticated', now(), now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000', 'invitee@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Invitee"}', 'authenticated', 'authenticated', now(), now());

-- Create household and membership
INSERT INTO public.households (id, name, created_by)
VALUES ('11111111-1111-1111-1111-111111111111', 'Test Household', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

INSERT INTO public.household_members (household_id, user_id, role)
VALUES ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner');

-- Create shared wallet + owner private wallet
INSERT INTO public.wallets (id, household_id, user_id, wallet_type, name) VALUES
  ('cccc1111-cccc-cccc-cccc-cccccccccccc', '11111111-1111-1111-1111-111111111111', NULL, 'shared', 'Shared Wallet'),
  ('aaaa1111-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'private', 'Owner Private');

-- Create invite
INSERT INTO public.household_invites (id, household_id, invited_by, invite_code, invite_token, expires_at)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  '11111111-1111-1111-1111-111111111111',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'ABCD1234',
  '33333333-3333-3333-3333-333333333333',
  now() + INTERVAL '7 days'
);

-- ============================================================
-- Act: User B accepts the invite
-- ============================================================
SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claims = '{"sub": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "role": "authenticated"}';

-- Call accept_invite as User B
SELECT public.accept_invite('33333333-3333-3333-3333-333333333333'::uuid);

-- ============================================================
-- Assert (as superuser to bypass RLS)
-- ============================================================
RESET role;

-- Test 1: household_members now has 2 rows
SELECT is(
  (SELECT count(*)::integer FROM public.household_members WHERE household_id = '11111111-1111-1111-1111-111111111111' AND left_at IS NULL),
  2,
  'Household has 2 active members after invite accepted'
);

-- Test 2: User B has a private wallet
SELECT is(
  (SELECT count(*)::integer FROM public.wallets WHERE user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND wallet_type = 'private'),
  1,
  'User B has a private wallet after accept_invite'
);

-- Test 3: User B's wallet has 8 default categories
SELECT is(
  (SELECT count(*)::integer FROM public.wallet_categories
   WHERE wallet_id = (SELECT id FROM public.wallets WHERE user_id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' AND wallet_type = 'private')),
  8,
  'User B private wallet has 8 default categories'
);

-- Test 4: Invite is marked as accepted
SELECT is(
  (SELECT accepted_by FROM public.household_invites WHERE id = '22222222-2222-2222-2222-222222222222'),
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid,
  'Invite is marked as accepted by User B'
);

-- Test 5: User B profile updated with household_id
SELECT is(
  (SELECT household_id FROM public.profiles WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'User B profile has household_id set'
);

SELECT * FROM finish();
ROLLBACK;
