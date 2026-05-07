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
  github_events?: { commits: number; repos: string[] };
  fitness_data?: Record<string, number>;
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
  const [daily, fitness, learning] = await Promise.all([
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
  ]);

  const fitness_data: Record<string, number> = {};
  for (const row of fitness.data ?? []) {
    fitness_data[row.metric as string] = Number(row.value);
  }

  const out: DayAggregate = {
    date,
    fitness_data,
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
