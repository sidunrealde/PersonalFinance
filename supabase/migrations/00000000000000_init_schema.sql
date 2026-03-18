-- Migration: Phase 1 active tables
-- Creates: profiles, households, household_members, household_invites, wallets, wallet_categories

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "pgtap" WITH SCHEMA extensions;

-- Private schema for helper functions
CREATE SCHEMA IF NOT EXISTS private;

-- ============================================================
-- profiles — extends auth.users
-- ============================================================
CREATE TABLE public.profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name    TEXT NOT NULL DEFAULT '',
  household_id    UUID,  -- FK added after households table
  onboarding_completed BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ
);

-- ============================================================
-- households — user-named household
-- ============================================================
CREATE TABLE public.households (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  created_by      UUID NOT NULL REFERENCES auth.users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ
);

-- Now add FK from profiles to households
ALTER TABLE public.profiles
  ADD CONSTRAINT fk_profiles_household
  FOREIGN KEY (household_id) REFERENCES public.households(id) ON DELETE SET NULL;

-- ============================================================
-- household_members — junction table
-- ============================================================
CREATE TABLE public.household_members (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id    UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role            TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'member')),
  joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at         TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (household_id, user_id)
);

-- ============================================================
-- household_invites — invite system
-- ============================================================
CREATE TABLE public.household_invites (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id    UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  invited_by      UUID NOT NULL REFERENCES auth.users(id),
  invite_code     TEXT NOT NULL UNIQUE,
  invite_token    UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  expires_at      TIMESTAMPTZ NOT NULL,
  accepted_by     UUID REFERENCES auth.users(id),
  accepted_at     TIMESTAMPTZ,
  revoked_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial indexes for active invites
CREATE INDEX idx_invites_token ON public.household_invites(invite_token)
  WHERE accepted_at IS NULL AND revoked_at IS NULL;
CREATE INDEX idx_invites_code ON public.household_invites(invite_code)
  WHERE accepted_at IS NULL AND revoked_at IS NULL;

-- ============================================================
-- wallets — 3 per household (shared + 2 private)
-- ============================================================
CREATE TABLE public.wallets (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  household_id    UUID NOT NULL REFERENCES public.households(id) ON DELETE CASCADE,
  user_id         UUID REFERENCES auth.users(id),
  wallet_type     TEXT NOT NULL CHECK (wallet_type IN ('shared', 'private')),
  name            TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ
);

CREATE INDEX idx_wallets_household ON public.wallets(household_id);
CREATE INDEX idx_wallets_user ON public.wallets(user_id) WHERE user_id IS NOT NULL;

-- ============================================================
-- wallet_categories — per-wallet categories
-- ============================================================
CREATE TABLE public.wallet_categories (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id       UUID NOT NULL REFERENCES public.wallets(id) ON DELETE CASCADE,
  name            TEXT NOT NULL,
  icon            TEXT,
  color           TEXT,
  sort_order      INTEGER NOT NULL DEFAULT 0,
  is_income       BOOLEAN NOT NULL DEFAULT false,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ,
  UNIQUE (wallet_id, name, is_income)
);

CREATE INDEX idx_categories_wallet ON public.wallet_categories(wallet_id);
