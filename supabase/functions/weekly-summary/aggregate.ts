import type { SupabaseClient } from '@supabase/supabase-js';

export interface DailyExcerpt {
  date: string;
  body: string;
  top_skill: string | null;
}

export interface WeekAggregate {
  week_start_date: string;
  week_end_date: string;
  total_commits: number;
  total_steps: number;
  total_protein_g: number;
  total_active_kcal: number;
  workouts: number;
  motorcycle_km: number;
  german_minutes: number;
  movies_watched: number;
  music_minutes: number;
  voice_notes: number;
  mood_average: number | null;
  top_skill_counts: Record<string, number>;
  daily_entries: DailyExcerpt[];
}

/** Aggregates an ISO week (Monday → Sunday inclusive) for one user.
 *  The shape is intentionally compact — the prompt scans for *shape*,
 *  not detail. Daily entries are included verbatim so the synthesiser
 *  can quote at most one line. */
export async function aggregateWeek(
  supabase: SupabaseClient,
  userId: string,
  weekStart: string,
  weekEnd: string,
): Promise<WeekAggregate> {
  const [
    githubRes,
    fitnessRes,
    workoutsRes,
    ridesRes,
    learningRes,
    moviesRes,
    musicRes,
    voiceRes,
    dailyRes,
    entriesRes,
  ] = await Promise.all([
    supabase
      .from('github_events')
      .select('event_type, commits')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('fitness_data')
      .select('metric, value')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('workouts')
      .select('id')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('motorcycle_rides')
      .select('distance_km')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('learning_logs')
      .select('track, minutes')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('movies_watched')
      .select('id')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('music_listens')
      .select('duration_sec')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('voice_notes')
      .select('id')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('daily_logs')
      .select('mood_score')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd),
    supabase
      .from('entries')
      .select('local_date, body, top_skill, status')
      .eq('user_id', userId)
      .gte('local_date', weekStart)
      .lte('local_date', weekEnd)
      .order('local_date'),
  ]);

  let totalCommits = 0;
  for (const r of (githubRes.data ?? []) as Array<{ event_type: string; commits: number }>) {
    if (r.event_type === 'push') totalCommits += r.commits ?? 0;
  }

  let totalSteps = 0;
  let totalProtein = 0;
  let totalActiveKcal = 0;
  for (const r of (fitnessRes.data ?? []) as Array<{ metric: string; value: number }>) {
    if (r.metric === 'steps') totalSteps += Number(r.value);
    if (r.metric === 'protein_g') totalProtein += Number(r.value);
    if (r.metric === 'calories') totalActiveKcal += Number(r.value);
  }

  let motorcycleKm = 0;
  for (const r of (ridesRes.data ?? []) as Array<{ distance_km: number }>) {
    motorcycleKm += Number(r.distance_km ?? 0);
  }

  let germanMinutes = 0;
  for (const r of (learningRes.data ?? []) as Array<{ track: string; minutes: number }>) {
    if (r.track === 'german') germanMinutes += Number(r.minutes ?? 0);
  }

  let musicSeconds = 0;
  for (const r of (musicRes.data ?? []) as Array<{ duration_sec: number }>) {
    musicSeconds += Number(r.duration_sec ?? 0);
  }

  const moods = ((dailyRes.data ?? []) as Array<{ mood_score: number | null }>)
    .map((d) => d.mood_score)
    .filter((m): m is number => m != null);
  const moodAverage = moods.length > 0
    ? Math.round((moods.reduce((a, b) => a + b, 0) / moods.length) * 10) / 10
    : null;

  const topSkillCounts: Record<string, number> = {};
  const dailyEntries: DailyExcerpt[] = [];
  for (const r of (entriesRes.data ?? []) as Array<{
    local_date: string;
    body: string | null;
    top_skill: string | null;
    status: string;
  }>) {
    if (r.status === 'ok' && r.body) {
      dailyEntries.push({
        date: r.local_date,
        body: r.body,
        top_skill: r.top_skill,
      });
    }
    if (r.top_skill) {
      topSkillCounts[r.top_skill] = (topSkillCounts[r.top_skill] ?? 0) + 1;
    }
  }

  return {
    week_start_date: weekStart,
    week_end_date: weekEnd,
    total_commits: totalCommits,
    total_steps: totalSteps,
    total_protein_g: Math.round(totalProtein),
    total_active_kcal: Math.round(totalActiveKcal),
    workouts: (workoutsRes.data ?? []).length,
    motorcycle_km: Math.round(motorcycleKm),
    german_minutes: germanMinutes,
    movies_watched: (moviesRes.data ?? []).length,
    music_minutes: Math.round(musicSeconds / 60),
    voice_notes: (voiceRes.data ?? []).length,
    mood_average: moodAverage,
    top_skill_counts: topSkillCounts,
    daily_entries: dailyEntries,
  };
}

export function isWeekEmpty(agg: WeekAggregate): boolean {
  return (
    agg.daily_entries.length === 0 &&
    agg.total_commits === 0 &&
    agg.total_steps === 0 &&
    agg.workouts === 0 &&
    agg.motorcycle_km === 0 &&
    agg.german_minutes === 0 &&
    agg.movies_watched === 0 &&
    agg.music_minutes === 0 &&
    agg.voice_notes === 0
  );
}
