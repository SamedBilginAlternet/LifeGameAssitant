-- 0002_logs.sql
-- Phase 1 schema: the tables the manual MVP and the daily-summary
-- Edge Function need to function end-to-end.

-- ─────────────────────────────────────────────────────────────────────
-- daily_logs — one row per user per local date. Mood + free note.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.daily_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  local_date  date not null,
  mood_score  int  check (mood_score between 1 and 10),
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, local_date)
);

drop trigger if exists daily_logs_touch on public.daily_logs;
create trigger daily_logs_touch
  before update on public.daily_logs
  for each row execute function public.touch_updated_at();

create index if not exists daily_logs_user_date_idx
  on public.daily_logs (user_id, local_date desc);

alter table public.daily_logs enable row level security;
drop policy if exists "daily_logs: own rows" on public.daily_logs;
create policy "daily_logs: own rows" on public.daily_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- fitness_data — one row per (date, metric). Latest write wins.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.fitness_data (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  local_date  date not null,
  metric      text not null
              check (metric in ('steps', 'calories', 'protein_g', 'weight_kg', 'workout_minutes')),
  value       numeric not null,
  source      text not null default 'manual'
              check (source in ('manual', 'health_connect', 'healthkit')),
  created_at  timestamptz not null default now(),
  unique (user_id, local_date, metric)
);

create index if not exists fitness_data_user_date_idx
  on public.fitness_data (user_id, local_date desc);

alter table public.fitness_data enable row level security;
drop policy if exists "fitness_data: own rows" on public.fitness_data;
create policy "fitness_data: own rows" on public.fitness_data
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- learning_logs — German, Master's, books, etc.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.learning_logs (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  local_date  date not null,
  track       text not null
              check (track in ('german', 'masters', 'algorithms', 'book', 'other')),
  minutes     int  not null check (minutes >= 0),
  topic       text,
  created_at  timestamptz not null default now()
);

create index if not exists learning_logs_user_date_idx
  on public.learning_logs (user_id, local_date desc);

alter table public.learning_logs enable row level security;
drop policy if exists "learning_logs: own rows" on public.learning_logs;
create policy "learning_logs: own rows" on public.learning_logs
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- entries — the diary itself. One row per user per local date.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  local_date    date not null,
  body          text,
  top_skill     text check (top_skill in ('logic', 'vitality', 'linguistics', 'culture', 'academic')),
  status        text not null default 'ok'
                check (status in ('ok', 'empty', 'failed')),
  model         text,
  stats_json    jsonb,
  generated_at  timestamptz not null default now(),
  unique (user_id, local_date)
);

create index if not exists entries_user_date_idx
  on public.entries (user_id, local_date desc);

alter table public.entries enable row level security;
drop policy if exists "entries: own rows read"  on public.entries;
drop policy if exists "entries: own rows write" on public.entries;
-- Users can read their own entries. Writes are reserved to the
-- daily-summary Edge Function, which uses the service role key and
-- bypasses RLS by design.
create policy "entries: own rows read" on public.entries
  for select using (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- integration_runs — audit log for the cron + poll Edge Functions.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.integration_runs (
  id        bigserial primary key,
  user_id   uuid references auth.users (id) on delete cascade,
  kind      text not null,
  status    text not null check (status in ('ok', 'error')),
  error     text,
  ran_at    timestamptz not null default now()
);

create index if not exists integration_runs_kind_ran_at_idx
  on public.integration_runs (kind, ran_at desc);

alter table public.integration_runs enable row level security;
drop policy if exists "integration_runs: own rows read" on public.integration_runs;
create policy "integration_runs: own rows read" on public.integration_runs
  for select using (auth.uid() = user_id);
-- Inserts come from Edge Functions only (service role).

-- ─────────────────────────────────────────────────────────────────────
-- Realtime: publish entries so the Flutter client sees today's row
-- appear without a manual refresh.
-- ─────────────────────────────────────────────────────────────────────

alter publication supabase_realtime add table public.entries;
