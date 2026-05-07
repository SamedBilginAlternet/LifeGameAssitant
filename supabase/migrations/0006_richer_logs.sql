-- 0006_richer_logs.sql
-- Phase 4 schema: meals, workouts (+sets), movies_watched, motorcycle_rides.

-- ─────────────────────────────────────────────────────────────────────
-- meals
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.meals (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users (id) on delete cascade,
  local_date  date not null,
  meal_type   text not null
              check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  title       text not null,
  calories    int  check (calories is null or calories >= 0),
  protein_g   numeric check (protein_g is null or protein_g >= 0),
  carbs_g     numeric check (carbs_g is null or carbs_g >= 0),
  photo_path  text,
  eaten_at    timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create index if not exists meals_user_date_idx on public.meals (user_id, local_date desc);

alter table public.meals enable row level security;
drop policy if exists "meals: own rows" on public.meals;
create policy "meals: own rows" on public.meals
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- workouts + workout_sets
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.workouts (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null references auth.users (id) on delete cascade,
  local_date      date not null,
  name            text not null,
  duration_min    int  check (duration_min is null or duration_min >= 0),
  total_volume_kg numeric default 0,
  notes           text,
  started_at      timestamptz not null default now(),
  created_at      timestamptz not null default now()
);

create index if not exists workouts_user_date_idx on public.workouts (user_id, local_date desc);

alter table public.workouts enable row level security;
drop policy if exists "workouts: own rows" on public.workouts;
create policy "workouts: own rows" on public.workouts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.workout_sets (
  id          uuid primary key default gen_random_uuid(),
  workout_id  uuid not null references public.workouts (id) on delete cascade,
  user_id     uuid not null references auth.users (id) on delete cascade,
  exercise    text not null,
  weight_kg   numeric not null check (weight_kg >= 0),
  reps        int not null check (reps > 0),
  rpe         int check (rpe is null or rpe between 1 and 10),
  set_index   int not null
);

create index if not exists workout_sets_workout_idx on public.workout_sets (workout_id);

alter table public.workout_sets enable row level security;
drop policy if exists "workout_sets: own rows" on public.workout_sets;
create policy "workout_sets: own rows" on public.workout_sets
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- movies_watched
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.movies_watched (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  local_date   date not null,
  tmdb_id      int,
  title        text not null,
  release_year int,
  poster_path  text,
  rating       int check (rating is null or rating between 1 and 5),
  medium       text check (medium is null or medium in ('cinema', 'streaming', 'tv')),
  watched_at   timestamptz not null default now(),
  created_at   timestamptz not null default now()
);

create index if not exists movies_watched_user_date_idx on public.movies_watched (user_id, local_date desc);

alter table public.movies_watched enable row level security;
drop policy if exists "movies_watched: own rows" on public.movies_watched;
create policy "movies_watched: own rows" on public.movies_watched
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────────────────────────────
-- motorcycle_rides
-- ─────────────────────────────────────────────────────────────────────

create table if not exists public.motorcycle_rides (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users (id) on delete cascade,
  local_date   date not null,
  distance_km  numeric not null check (distance_km >= 0),
  duration_min int check (duration_min is null or duration_min >= 0),
  route_tag    text,
  notes        text,
  created_at   timestamptz not null default now()
);

create index if not exists motorcycle_rides_user_date_idx on public.motorcycle_rides (user_id, local_date desc);

alter table public.motorcycle_rides enable row level security;
drop policy if exists "motorcycle_rides: own rows" on public.motorcycle_rides;
create policy "motorcycle_rides: own rows" on public.motorcycle_rides
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
