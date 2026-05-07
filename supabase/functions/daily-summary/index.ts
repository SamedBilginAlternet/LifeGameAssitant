/**
 * daily-summary — the nightly narrator.
 *
 * Two invocation modes:
 *
 *   1. Cron (no body, or { mode: 'cron' }):
 *      Iterates every active profile and summarizes the day for users
 *      whose local time has crossed their summary_time. Called by
 *      pg_cron at 23:50 UTC; the function does the per-user timezone
 *      math itself so a single schedule covers everyone.
 *
 *   2. On-demand ({ mode: 'user', user_id, date }):
 *      Summarizes a single user/date. Used for manual re-runs from the
 *      app's pull-to-refresh and for testing.
 *
 * The Edge Function uses the service role key — it bypasses RLS to
 * write the entries row. Validation of who-is-allowed-what happens at
 * the schema level (entries has a SELECT-only policy for end users).
 */

import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { aggregateDay, isEmptyAggregate } from './aggregate.ts';
import { callGroq } from './groq.ts';
import { systemPromptFor, type Voice } from './prompts.ts';

const PRIMARY_MODEL = 'llama-3.3-70b-versatile';
const FALLBACK_MODEL = 'llama-3.1-8b-instant';

const Body = z.union([
  z.object({ mode: z.literal('cron').optional() }),
  z.object({
    mode: z.literal('user'),
    user_id: z.string().uuid(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  }),
]);

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, error: 'method_not_allowed' }, { status: 405 });
  }

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY');

  if (!SUPABASE_URL || !SERVICE_ROLE || !GROQ_API_KEY) {
    return Response.json(
      { ok: false, error: 'missing_env' },
      { status: 500 },
    );
  }

  const raw = req.headers.get('content-length') === '0' ? {} : await req.json().catch(() => ({}));
  const parsed = Body.safeParse(raw);
  if (!parsed.success) {
    return Response.json({ ok: false, error: 'bad_input', detail: parsed.error.message }, { status: 400 });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  const targets = await resolveTargets(supabase, parsed.data);
  const results = await Promise.allSettled(
    targets.map((t) => runOne(supabase, GROQ_API_KEY, t)),
  );

  const summary = {
    ok: true,
    targets: targets.length,
    succeeded: results.filter((r) => r.status === 'fulfilled' && r.value === 'ok').length,
    empty: results.filter((r) => r.status === 'fulfilled' && r.value === 'empty').length,
    failed: results.filter((r) => r.status === 'rejected' || (r.status === 'fulfilled' && r.value === 'failed')).length,
  };

  return Response.json(summary);
});

interface Target {
  user_id: string;
  date: string;
  voice: Voice;
}

type ParsedBody = z.infer<typeof Body>;

async function resolveTargets(supabase: ReturnType<typeof createClient>, body: ParsedBody): Promise<Target[]> {
  if ('mode' in body && body.mode === 'user') {
    const { data: profile } = await supabase
      .from('profiles')
      .select('narrator_voice')
      .eq('id', body.user_id)
      .maybeSingle();
    return [{
      user_id: body.user_id,
      date: body.date,
      voice: (profile?.narrator_voice as Voice) ?? 'mentor',
    }];
  }

  // Cron mode: walk every profile, decide based on the user's timezone
  // whether their summary_time has passed for the local "yesterday".
  const { data: profiles } = await supabase
    .from('profiles')
    .select('id, timezone, summary_time, narrator_voice');

  const now = new Date();
  const targets: Target[] = [];
  for (const p of profiles ?? []) {
    const localNow = new Date(now.toLocaleString('en-US', { timeZone: p.timezone ?? 'UTC' }));
    const [hh, mm] = String(p.summary_time ?? '23:50').split(':').map(Number);
    const summaryToday = new Date(localNow);
    summaryToday.setHours(hh, mm, 0, 0);

    if (localNow >= summaryToday) {
      const date = formatLocalDate(localNow);
      targets.push({
        user_id: p.id,
        date,
        voice: (p.narrator_voice as Voice) ?? 'mentor',
      });
    }
  }
  return targets;
}

function formatLocalDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

async function runOne(
  supabase: ReturnType<typeof createClient>,
  apiKey: string,
  t: Target,
): Promise<'ok' | 'empty' | 'failed'> {
  try {
    const aggregate = await aggregateDay(supabase, t.user_id, t.date);
    if (isEmptyAggregate(aggregate)) {
      await supabase.from('entries').upsert({
        user_id: t.user_id,
        local_date: t.date,
        status: 'empty',
        body: null,
        stats_json: { date: t.date },
      }, { onConflict: 'user_id,local_date' });
      await logRun(supabase, t.user_id, 'ok');
      return 'empty';
    }

    const compassionate = (aggregate.mood_score ?? 10) < 4;
    const systemPrompt = systemPromptFor(t.voice, { compassionate });

    let result;
    try {
      result = await callGroq({
        apiKey,
        model: PRIMARY_MODEL,
        systemPrompt,
        userPayload: aggregate,
      });
    } catch {
      // One retry on the smaller model, lower temperature.
      result = await callGroq({
        apiKey,
        model: FALLBACK_MODEL,
        systemPrompt,
        userPayload: aggregate,
        temperature: 0.3,
      });
    }

    await supabase.from('entries').upsert({
      user_id: t.user_id,
      local_date: t.date,
      body: result.output.body,
      top_skill: result.output.top_skill,
      status: 'ok',
      model: result.rawModel,
      stats_json: aggregate,
    }, { onConflict: 'user_id,local_date' });

    await logRun(supabase, t.user_id, 'ok');
    return 'ok';
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await supabase.from('entries').upsert({
      user_id: t.user_id,
      local_date: t.date,
      status: 'failed',
      body: null,
      stats_json: { error: msg },
    }, { onConflict: 'user_id,local_date' });
    await logRun(supabase, t.user_id, 'error', msg);
    return 'failed';
  }
}

async function logRun(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  status: 'ok' | 'error',
  error?: string,
): Promise<void> {
  await supabase.from('integration_runs').insert({
    user_id: userId,
    kind: 'daily_summary',
    status,
    error: error ?? null,
  });
}
