-- 0004_integrations.sql
-- Phase 3 schema: per-user third-party tokens + github_events.

-- ─────────────────────────────────────────────────────────────────────
-- integrations — third-party credentials per user.
--
-- IMPORTANT: github_token is stored as plain text here for simplicity.
-- For production multi-user use, wrap it via Supabase Vault:
--   1. enable the `vault` extension
--   2. replace github_token with vault.create_secret() reference
--   3. read via vault.decrypted_secrets
-- The Edge Function code already isolates the read site so the migration
-- to Vault only touches one query.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.integrations (
  user_id        uuid primary key references auth.users (id) on delete cascade,
  github_token   text,
  github_login   text,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

drop trigger if exists integrations_touch on public.integrations;
create trigger integrations_touch
  before update on public.integrations
  for each row execute function public.touch_updated_at();

alter table public.integrations enable row level security;

drop policy if exists "integrations: own row read"   on public.integrations;
drop policy if exists "integrations: own row update" on public.integrations;
drop policy if exists "integrations: own row insert" on public.integrations;
drop policy if exists "integrations: own row delete" on public.integrations;

create policy "integrations: own row read" on public.integrations
  for select using (auth.uid() = user_id);
create policy "integrations: own row update" on public.integrations
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "integrations: own row insert" on public.integrations
  for insert with check (auth.uid() = user_id);
create policy "integrations: own row delete" on public.integrations
  for delete using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- github_events — one row per ingested event.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.github_events (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  github_id     text not null,                       -- GitHub event id, for dedupe
  local_date    date not null,
  event_type    text not null
                check (event_type in ('push', 'pr_opened', 'pr_merged', 'issue_opened', 'issue_closed')),
  repo          text not null,
  commits       int  not null default 0,
  payload       jsonb,
  occurred_at   timestamptz not null,
  unique (user_id, github_id)
);

create index if not exists github_events_user_date_idx
  on public.github_events (user_id, local_date desc);

alter table public.github_events enable row level security;
drop policy if exists "github_events: own rows read" on public.github_events;
create policy "github_events: own rows read" on public.github_events
  for select using (auth.uid() = user_id);
-- Inserts only via the github-poll Edge Function (service role).
