-- pgTAP test: Invite edge cases
-- Expired, accepted, and revoked invites must be rejected.
-- Run with: npx supabase test db

BEGIN;
SELECT plan(4);

-- ============================================================
-- Setup: create users and household
-- ============================================================
INSERT INTO auth.users (id, instance_id, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '00000000-0000-0000-0000-000000000000', 'owner@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Owner"}', 'authenticated', 'authenticated', now(), now()),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', '00000000-0000-0000-0000-000000000000', 'invitee@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{"display_name":"Invitee"}', 'authenticated', 'authenticated', now(), now());

INSERT INTO public.households (id, name, created_by)
VALUES ('11111111-1111-1111-1111-111111111111', 'Test Household', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

INSERT INTO public.household_members (household_id, user_id, role)
VALUES ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'owner');

-- Create 3 invites: expired, already-accepted, revoked
INSERT INTO public.household_invites (id, household_id, invited_by, invite_code, invite_token, expires_at) VALUES
  ('ee000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'EXPIRED1', 'ee000000-0000-0000-0000-000000000011', now() - INTERVAL '1 day');

INSERT INTO public.household_invites (id, household_id, invited_by, invite_code, invite_token, expires_at, accepted_at, accepted_by) VALUES
  ('ee000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ACCEPT12', 'ee000000-0000-0000-0000-000000000022', now() + INTERVAL '7 days', now(), 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');

INSERT INTO public.household_invites (id, household_id, invited_by, invite_code, invite_token, expires_at, revoked_at) VALUES
  ('ee000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'REVOKE12', 'ee000000-0000-0000-0000-000000000033', now() + INTERVAL '7 days', now());

-- Also create a valid invite for the success case
INSERT INTO public.household_invites (id, household_id, invited_by, invite_code, invite_token, expires_at) VALUES
  ('ee000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'VALID123', 'ee000000-0000-0000-0000-000000000044', now() + INTERVAL '7 days');

-- ============================================================
-- Act as User B
-- ============================================================
SET LOCAL role = 'authenticated';
SET LOCAL request.jwt.claims = '{"sub": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", "role": "authenticated"}';

-- Test 1: Expired invite raises exception
SELECT throws_ok(
  $$ SELECT public.accept_invite('ee000000-0000-0000-0000-000000000011'::uuid) $$,
  'Invalid or expired invite',
  'Expired invite is rejected'
);

-- Test 2: Already-accepted invite raises exception
SELECT throws_ok(
  $$ SELECT public.accept_invite('ee000000-0000-0000-0000-000000000022'::uuid) $$,
  'Invalid or expired invite',
  'Already-accepted invite is rejected'
);

-- Test 3: Revoked invite raises exception
SELECT throws_ok(
  $$ SELECT public.accept_invite('ee000000-0000-0000-0000-000000000033'::uuid) $$,
  'Invalid or expired invite',
  'Revoked invite is rejected'
);

-- Test 4: Valid invite succeeds (returns household_id)
SELECT is(
  public.accept_invite('ee000000-0000-0000-0000-000000000044'::uuid),
  '11111111-1111-1111-1111-111111111111'::uuid,
  'Valid invite returns household_id'
);

SELECT * FROM finish();
ROLLBACK;
