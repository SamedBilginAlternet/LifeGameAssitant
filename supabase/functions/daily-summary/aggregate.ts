import type { SupabaseClient } from '@supabase/supabase-js';

/** Strips empty arrays + null/zero leaves so the model isn't tempted
 *  to hallucinate against data that was never captured. */
export function pruneEmpty<T>(input: T): T {
  if (Array.isArray(input)) {
    const cleaned = input
      .map(pruneEmpty)
      .filter((v) => v !== null && v !== undefined);
    return cleaned as unknown as T;
  }
  if (input && typeof input === 'object') {
    const out: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(input as Record<string, unknown>)) {
      const cleaned = pruneEmpty(v);
      if (cleaned === null || cleaned === undefined) continue;
      if (Array.isArray(cleaned) && cleaned.length === 0) continue;
      if (typeof cleaned === 'object' && Object.keys(cleaned).length === 0) continue;
      out[k] = cleaned;
    }
    return out as T;
  }
  return input;
}

export interface DayAggregate {
  date: string;
  github_events?: { commits: number; prs_opened: number; prs_merged: number; repos: string[] };
  fitness_data?: Record<string, number>;
  workouts?: Array<{ name: string; duration_min?: number | null; total_volume_kg?: number | null }>;
  meals?: Array<{ type: string; title: string; protein_g?: number | null }>;
  movies_watched?: Array<{ title: string; year?: number | null; rating?: number | null; medium?: string | null }>;
  motorcycle_rides?: Array<{ distance_km: number; route_tag?: string | null }>;
  music?: {
    top_track?: { title: string; artist: string; play_count: number };
    top_artist?: { name: string; play_count: number };
    total_minutes: number;
  };
  cover_photo?: { present: boolean; dominant_hex?: string | null };
  learning_logs?: Array<{ track: string; minutes: number; topic?: string | null }>;
  mood_score?: number;
  note?: string | null;
}

/** Aggregates one user's day across the Phase 1 tables. Phase 4+ tables
 *  (workouts, meals, music, voice notes) get added here as they ship. */
export async function aggregateDay(
  supabase: SupabaseClient,
  userId: string,
  date: string,
): Promise<DayAggregate> {
  const [daily, fitness, learning, github, workouts, meals, movies, rides, music, cover] = await Promise.all([
    supabase
      .from('daily_logs')
      .select('mood_score, note')
      .eq('user_id', userId)
      .eq('local_date', date)
      .maybeSingle(),
    supabase
      .from('fitness_data')
      .select('metric, value')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('learning_logs')
      .select('track, minutes, topic')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('github_events')
      .select('event_type, repo, commits')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('workouts')
      .select('name, duration_min, total_volume_kg')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('meals')
      .select('meal_type, title, protein_g')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('movies_watched')
      .select('title, release_year, rating, medium')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('motorcycle_rides')
      .select('distance_km, route_tag')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('music_listens')
      .select('track_title, artist, duration_sec')
      .eq('user_id', userId)
      .eq('local_date', date),
    supabase
      .from('media_assets')
      .select('dominant_hex')
      .eq('user_id', userId)
      .eq('local_date', date)
      .eq('kind', 'cover')
      .maybeSingle(),
  ]);

  const fitness_data: Record<string, number> = {};
  for (const row of fitness.data ?? []) {
    fitness_data[row.metric as string] = Number(row.value);
  }

  let github_events: DayAggregate['github_events'] | undefined;
  const ghRows = github.data ?? [];
  if (ghRows.length > 0) {
    let commits = 0;
    let prs_opened = 0;
    let prs_merged = 0;
    const repoSet = new Set<string>();
    for (const r of ghRows as Array<{ event_type: string; repo: string; commits: number }>) {
      if (r.event_type === 'push') commits += r.commits ?? 0;
      if (r.event_type === 'pr_opened') prs_opened++;
      if (r.event_type === 'pr_merged') prs_merged++;
      repoSet.add(r.repo);
    }
    github_events = { commits, prs_opened, prs_merged, repos: [...repoSet] };
  }

  const musicRows = (music.data ?? []) as Array<{ track_title: string; artist: string; duration_sec: number }>;
  let musicSummary: DayAggregate['music'];
  if (musicRows.length > 0) {
    const trackCounts = new Map<string, { title: string; artist: string; count: number }>();
    const artistCounts = new Map<string, number>();
    let totalSec = 0;
    for (const r of musicRows) {
      const tk = `${r.artist}::${r.track_title}`;
      const cur = trackCounts.get(tk);
      trackCounts.set(tk, { title: r.track_title, artist: r.artist, count: (cur?.count ?? 0) + 1 });
      artistCounts.set(r.artist, (artistCounts.get(r.artist) ?? 0) + 1);
      totalSec += r.duration_sec ?? 0;
    }
    const topTrack = [...trackCounts.values()].sort((a, b) => b.count - a.count)[0];
    const topArtistEntry = [...artistCounts.entries()].sort((a, b) => b[1] - a[1])[0];
    musicSummary = {
      total_minutes: Math.round(totalSec / 60),
      top_track: topTrack ? { title: topTrack.title, artist: topTrack.artist, play_count: topTrack.count } : undefined,
      top_artist: topArtistEntry ? { name: topArtistEntry[0], play_count: topArtistEntry[1] } : undefined,
    };
  }

  const coverRow = cover.data as { dominant_hex: string | null } | null;
  const coverSummary = coverRow != null
      ? { present: true, dominant_hex: coverRow.dominant_hex }
      : undefined;

  const mealRows = (meals.data ?? []) as Array<{ meal_type: string; title: string; protein_g: number | null }>;
  const movieRows = (movies.data ?? []) as Array<{ title: string; release_year: number | null; rating: number | null; medium: string | null }>;
  const out: DayAggregate = {
    date,
    github_events,
    fitness_data,
    workouts: (workouts.data ?? []) as DayAggregate['workouts'],
    meals: mealRows.map((m) => ({ type: m.meal_type, title: m.title, protein_g: m.protein_g })),
    movies_watched: movieRows.map((mv) => ({
      title: mv.title,
      year: mv.release_year,
      rating: mv.rating,
      medium: mv.medium,
    })),
    motorcycle_rides: (rides.data ?? []) as DayAggregate['motorcycle_rides'],
    music: musicSummary,
    cover_photo: coverSummary,
    learning_logs: (learning.data ?? []) as DayAggregate['learning_logs'],
    mood_score: daily.data?.mood_score ?? undefined,
    note: daily.data?.note ?? null,
  };

  return pruneEmpty(out);
}

export function isEmptyAggregate(agg: DayAggregate): boolean {
  // 'date' is always present — we ignore it for the empty check.
  const { date: _date, ...rest } = agg;
  return Object.keys(rest).length === 0;
}
