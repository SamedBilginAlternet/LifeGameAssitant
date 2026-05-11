/**
 * weekly-summary — Sunday synthesist.
 *
 * Mirrors daily-summary's invocation modes:
 *   1. Cron ({ mode: 'cron' } or empty body):
 *      Iterates every profile, picks users whose local Sunday-evening
 *      synthesis time has just passed, runs the synthesis once.
 *
 *   2. On-demand ({ mode: 'user', user_id, week_start_date }):
 *      Runs a synthesis for one user / one ISO week. Used for
 *      manual re-runs and tests.
 *
 * Uses the service role to bypass RLS for the upsert into
 * weekly_summaries (end users have SELECT-only via policy).
 */

import { createClient } from '@supabase/supabase-js';
import { z } from 'zod';
import { aggregateWeek, isWeekEmpty } from './aggregate.ts';
import { systemPromptFor, type Voice } from './prompts.ts';

const PRIMARY_MODEL = 'llama-3.3-70b-versatile';
const FALLBACK_MODEL = 'llama-3.1-8b-instant';

const Body = z.union([
  z.object({ mode: z.literal('cron').optional() }),
  z.object({
    mode: z.literal('user'),
    user_id: z.string().uuid(),
    week_start_date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  }),
]);

interface Target {
  user_id: string;
  week_start_date: string;
  week_end_date: string;
  voice: Voice;
}

type ParsedBody = z.infer<typeof Body>;

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, error: 'method_not_allowed' }, { status: 405 });
  }

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY');

  if (!SUPABASE_URL || !SERVICE_ROLE || !GROQ_API_KEY) {
    return Response.json({ ok: false, error: 'missing_env' }, { status: 500 });
  }

  const raw = req.headers.get('content-length') === '0' ? {} : await req.json().catch(() => ({}));
  const parsed = Body.safeParse(raw);
  if (!parsed.success) {
    return Response.json(
      { ok: false, error: 'bad_input', detail: parsed.error.message },
      { status: 400 },
    );
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);
  const targets = await resolveTargets(supabase, parsed.data);
  const results = await Promise.allSettled(
    targets.map((t) => runOne(supabase, GROQ_API_KEY, t)),
  );

  return Response.json({
    ok: true,
    targets: targets.length,
    succeeded: results.filter((r) => r.status === 'fulfilled' && r.value === 'ok').length,
    empty: results.filter((r) => r.status === 'fulfilled' && r.value === 'empty').length,
    failed: results.filter((r) => r.status === 'rejected' || (r.status === 'fulfilled' && r.value === 'failed')).length,
  });
});

async function resolveTargets(
  supabase: ReturnType<typeof createClient>,
  body: ParsedBody,
): Promise<Target[]> {
  if ('mode' in body && body.mode === 'user') {
    const { data: profile } = await supabase
      .from('profiles')
      .select('narrator_voice')
      .eq('id', body.user_id)
      .maybeSingle();
    const start = new Date(body.week_start_date);
    const end = new Date(start);
    end.setUTCDate(end.getUTCDate() + 6);
    return [{
      user_id: body.user_id,
      week_start_date: body.week_start_date,
      week_end_date: formatDate(end),
      voice: (profile?.narrator_voice as Voice) ?? 'mentor',
    }];
  }

  // Cron mode: walk profiles, pick users whose local time is Sunday
  // past their summary_time. Summary_time is the daily 23:50 anchor,
  // but the weekly cron fires at :30 each hour so we shift the
  // threshold 20 minutes earlier so the weekly entry always lands
  // before the daily one for the same Sunday.
  const { data: profiles } = await supabase
    .from('profiles')
    .select('id, timezone, summary_time, narrator_voice');

  const now = new Date();
  const targets: Target[] = [];
  for (const p of profiles ?? []) {
    const localNow = new Date(
      now.toLocaleString('en-US', { timeZone: p.timezone ?? 'UTC' }),
    );
    if (localNow.getDay() !== 0) continue; // 0 = Sunday in local time

    const [hh, mm] = String(p.summary_time ?? '23:50').split(':').map(Number);
    const thresholdMins = hh * 60 + mm - 20;
    const localMins = localNow.getHours() * 60 + localNow.getMinutes();
    if (localMins < thresholdMins) continue;

    // ISO week start = Monday before today.
    const weekEnd = new Date(localNow);
    weekEnd.setHours(0, 0, 0, 0);
    const weekStart = new Date(weekEnd);
    weekStart.setDate(weekStart.getDate() - 6);

    targets.push({
      user_id: p.id,
      week_start_date: formatDate(weekStart),
      week_end_date: formatDate(weekEnd),
      voice: (p.narrator_voice as Voice) ?? 'mentor',
    });
  }
  return targets;
}

function formatDate(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

interface DiaryOutput {
  body: string;
  top_skill: 'logic' | 'vitality' | 'linguistics' | 'culture' | 'academic';
}

async function runOne(
  supabase: ReturnType<typeof createClient>,
  apiKey: string,
  t: Target,
): Promise<'ok' | 'empty' | 'failed'> {
  try {
    const aggregate = await aggregateWeek(
      supabase,
      t.user_id,
      t.week_start_date,
      t.week_end_date,
    );

    if (isWeekEmpty(aggregate)) {
      await supabase.from('weekly_summaries').upsert({
        user_id: t.user_id,
        week_start_date: t.week_start_date,
        week_end_date: t.week_end_date,
        status: 'empty',
        body: null,
        raw: aggregate,
      }, { onConflict: 'user_id,week_start_date' });
      return 'empty';
    }

    const compassionate = (aggregate.mood_average ?? 10) < 4;
    const systemPrompt = systemPromptFor(t.voice, { compassionate });

    let output: DiaryOutput;
    try {
      output = await callGroq(apiKey, PRIMARY_MODEL, systemPrompt, aggregate, 0.7);
    } catch {
      output = await callGroq(apiKey, FALLBACK_MODEL, systemPrompt, aggregate, 0.3);
    }

    await supabase.from('weekly_summaries').upsert({
      user_id: t.user_id,
      week_start_date: t.week_start_date,
      week_end_date: t.week_end_date,
      body: output.body,
      top_skill: output.top_skill,
      status: 'ok',
      raw: aggregate,
      error: null,
    }, { onConflict: 'user_id,week_start_date' });
    return 'ok';
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await supabase.from('weekly_summaries').upsert({
      user_id: t.user_id,
      week_start_date: t.week_start_date,
      week_end_date: t.week_end_date,
      status: 'failed',
      error: msg,
    }, { onConflict: 'user_id,week_start_date' });
    return 'failed';
  }
}

async function callGroq(
  apiKey: string,
  model: string,
  systemPrompt: string,
  userPayload: unknown,
  temperature: number,
): Promise<DiaryOutput> {
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      model,
      temperature,
      max_tokens: 600,
      response_format: { type: 'json_object' },
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: JSON.stringify(userPayload) },
      ],
    }),
    signal: AbortSignal.timeout(20_000),
  });
  if (!res.ok) {
    throw new Error(`groq ${res.status}: ${(await res.text()).slice(0, 200)}`);
  }
  const json = await res.json();
  const content: string | undefined = json?.choices?.[0]?.message?.content;
  if (!content) throw new Error('groq returned no content');

  let parsed: unknown;
  try {
    parsed = JSON.parse(content);
  } catch {
    throw new Error(`groq returned non-JSON: ${content.slice(0, 200)}`);
  }

  if (!parsed || typeof parsed !== 'object') {
    throw new Error('output not an object');
  }
  const r = parsed as Record<string, unknown>;
  if (typeof r.body !== 'string' || r.body.length === 0) {
    throw new Error('output.body missing or empty');
  }
  const allowed = ['logic', 'vitality', 'linguistics', 'culture', 'academic'];
  if (typeof r.top_skill !== 'string' || !allowed.includes(r.top_skill)) {
    throw new Error(`output.top_skill invalid: ${r.top_skill}`);
  }
  return { body: r.body, top_skill: r.top_skill as DiaryOutput['top_skill'] };
}
