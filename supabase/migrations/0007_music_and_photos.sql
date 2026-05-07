-- 0007_music_and_photos.sql
-- Phase 4.5 schema: music_listens, media_assets, Spotify columns on
-- integrations, Storage buckets for cover photos.

-- ─────────────────────────────────────────────────────────────────────
-- integrations: extend with Spotify columns
-- ─────────────────────────────────────────────────────────────────────

alter table public.integrations
  add column if not exists spotify_refresh_token text,
  add column if not exists spotify_user_id       text,
  add column if not exists spotify_last_polled   timestamptz;

-- ─────────────────────────────────────────────────────────────────────
-- music_listens — one row per played track. Filled by spotify-poll.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.music_listens (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  local_date   date not null,
  source       text not null check (source in ('spotify', 'lastfm', 'manual')),
  track_id     text not null,
  track_title  text not null,
  artist       text not null,
  album        text,
  duration_sec int not null default 0,
  played_at    timestamptz not null,
  unique (user_id, source, track_id, played_at)
);

create index if not exists music_listens_user_date_idx
  on public.music_listens (user_id, local_date desc);
create index if not exists music_listens_user_played_idx
  on public.music_listens (user_id, played_at desc);

alter table public.music_listens enable row level security;
drop policy if exists "music_listens: own rows read" on public.music_listens;
create policy "music_listens: own rows read" on public.music_listens
  for select using (auth.uid() = user_id);
-- Inserts via Edge Function (service role) only.

-- ─────────────────────────────────────────────────────────────────────
-- media_assets — cover photos, voice memos, meal photos, movie posters.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.media_assets (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users (id) on delete cascade,
  local_date    date,
  kind          text not null check (kind in ('cover', 'voice', 'meal_photo', 'movie_poster')),
  source        text default 'user_upload'
                check (source in ('user_upload', 'auto_pick', 'pixel_icon')),
  storage_path  text not null,
  width         int,
  height        int,
  dominant_hex  text,
  created_at    timestamptz not null default now()
);

create index if not exists media_assets_user_date_kind_idx
  on public.media_assets (user_id, local_date, kind);

-- One cover per day per user (the "daily photo"). Other kinds are
-- unlimited.
create unique index if not exists media_assets_one_cover_per_day
  on public.media_assets (user_id, local_date)
  where kind = 'cover';

alter table public.media_assets enable row level security;
drop policy if exists "media_assets: own rows" on public.media_assets;
create policy "media_assets: own rows" on public.media_assets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- Storage buckets
--
-- Both private. Bucket policies mirror the RLS rule on media_assets:
-- objects are scoped under <user_id>/... and only the owner can read.
-- ─────────────────────────────────────────────────────────────────────

insert into storage.buckets (id, name, public)
values ('covers', 'covers', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('voice', 'voice', false)
on conflict (id) do nothing;

drop policy if exists "covers: owner read"   on storage.objects;
drop policy if exists "covers: owner write"  on storage.objects;
drop policy if exists "covers: owner update" on storage.objects;
drop policy if exists "covers: owner delete" on storage.objects;
drop policy if exists "voice: owner read"    on storage.objects;
drop policy if exists "voice: owner write"   on storage.objects;
drop policy if exists "voice: owner update"  on storage.objects;
drop policy if exists "voice: owner delete"  on storage.objects;

create policy "covers: owner read" on storage.objects
  for select using (bucket_id = 'covers' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "covers: owner write" on storage.objects
  for insert with check (bucket_id = 'covers' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "covers: owner update" on storage.objects
  for update using (bucket_id = 'covers' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "covers: owner delete" on storage.objects
  for delete using (bucket_id = 'covers' and auth.uid()::text = (storage.foldername(name))[1]);

create policy "voice: owner read" on storage.objects
  for select using (bucket_id = 'voice' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "voice: owner write" on storage.objects
  for insert with check (bucket_id = 'voice' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "voice: owner update" on storage.objects
  for update using (bucket_id = 'voice' and auth.uid()::text = (storage.foldername(name))[1]);
create policy "voice: owner delete" on storage.objects
  for delete using (bucket_id = 'voice' and auth.uid()::text = (storage.foldername(name))[1]);
