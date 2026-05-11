-- 0010_weekly_summaries.sql
-- Phase 7+ schema: one row per ISO-week per user. Filled by the
-- weekly-summary Edge Function on Sundays — see 0011 for the schedule.
--
-- Weekly entries are deliberately a separate table from `entries`
-- (which holds one row per day). Reusing entries with a kind enum was
-- considered and rejected — the daily timeline query would always have
-- to filter by kind and the unique constraint on (user_id, local_date)
-- doesn't compose with weekly dates cleanly.

create table if not exists public.weekly_summaries (
  user_id          uuid not null references auth.users (id) on delete cascade,
  week_start_date  date not null,  -- Monday (ISO week)
  week_end_date    date not null,  -- Sunday
  body             text,
  top_skill        text check (top_skill in
                       ('logic','vitality','linguistics','culture','academic')),
  status           text not null default 'pending'
                     check (status in ('pending','ok','empty','failed')),
  raw              jsonb,           -- the aggregate the model saw
  error            text,
  created_at       timestamptz not null default now(),
  primary key (user_id, week_start_date)
);

create index if not exists weekly_summaries_user_week_idx
  on public.weekly_summaries (user_id, week_start_date desc);

alter table public.weekly_summaries enable row level security;
drop policy if exists "weekly_summaries: own rows read" on public.weekly_summaries;
create policy "weekly_summaries: own rows read"
  on public.weekly_summaries
  for select using (auth.uid() = user_id);

-- Inserts/updates come from the Edge Function (service role) only.

-- Realtime — the app subscribes so a fresh weekly entry appears on its
-- own in the same way daily entries do.
alter publication supabase_realtime add table public.weekly_summaries;
