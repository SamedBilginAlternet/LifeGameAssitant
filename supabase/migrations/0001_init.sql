-- 0001_init.sql
-- Foundational schema: profiles + RLS + on-signup trigger.
--
-- Every subsequent table will follow the same template:
--   user_id uuid references auth.users
--   RLS policy: auth.uid() = user_id
--
-- Run this against an empty Supabase project before launching the app
-- for the first time. Idempotent — safe to re-run.

-- ─────────────────────────────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.profiles (
  id              uuid primary key references auth.users (id) on delete cascade,
  display_name    text,
  timezone        text not null default 'UTC',
  summary_time    time not null default '23:50',
  narrator_voice  text not null default 'mentor'
                  check (narrator_voice in ('mentor', 'historian', 'transmission')),
  palette         text not null default 'amber'
                  check (palette in ('amber', 'phosphor')),
  german_level    text not null default 'A2',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.profiles is
  'One row per user. Created by the on-signup trigger below.';

-- updated_at touch trigger
create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
  before update on public.profiles
  for each row execute function public.touch_updated_at();

-- ─────────────────────────────────────────────────────────────────────
-- Row-Level Security
-- ─────────────────────────────────────────────────────────────────────

alter table public.profiles enable row level security;

drop policy if exists "profiles: own row read"   on public.profiles;
drop policy if exists "profiles: own row update" on public.profiles;
drop policy if exists "profiles: own row insert" on public.profiles;

create policy "profiles: own row read"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles: own row update"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

create policy "profiles: own row insert"
  on public.profiles for insert
  with check (auth.uid() = id);

-- ─────────────────────────────────────────────────────────────────────
-- On-signup trigger: auto-create a profiles row when auth.users grows.
--
-- SECURITY DEFINER bypasses the RLS write check above — without it,
-- the trigger would run as the new user before their JWT is established
-- and the insert would fail.
-- ─────────────────────────────────────────────────────────────────────

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1)
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
