-- 0009_voice.sql
-- Phase 5 schema: voice_notes (recordings + transcript + translation +
-- A2 corrections). The `voice` Storage bucket and its RLS policies were
-- already provisioned in 0007.

-- ─────────────────────────────────────────────────────────────────────
-- voice_notes — one row per recording. Created up-front when the
-- mobile app uploads the audio file to storage; the voice-transcribe
-- Edge Function later fills in transcript_de / transcript_en /
-- corrections.
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.voice_notes (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  local_date      date not null,
  storage_path    text not null,
  duration_sec    int not null default 0,
  language        text,                  -- ISO code returned by whisper
  transcript_de   text,                  -- raw transcript (likely German)
  transcript_en   text,                  -- English translation
  corrections     jsonb,                 -- [{ original, corrected, note }]
  status          text not null default 'pending'
                    check (status in ('pending', 'ok', 'failed')),
  error           text,
  created_at      timestamptz not null default now(),
  processed_at    timestamptz
);

create index if not exists voice_notes_user_date_idx
  on public.voice_notes (user_id, local_date);

-- One recording per day per user keeps the diary page focused. Re-
-- recording on the same day overwrites the storage object and resets
-- transcription status; the unique index makes that explicit.
create unique index if not exists voice_notes_one_per_day
  on public.voice_notes (user_id, local_date);

alter table public.voice_notes enable row level security;
drop policy if exists "voice_notes: own rows" on public.voice_notes;
create policy "voice_notes: own rows" on public.voice_notes
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
