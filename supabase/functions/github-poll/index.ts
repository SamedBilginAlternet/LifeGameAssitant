/**
 * github-poll — runs every 30 minutes via pg_cron.
 *
 * For every integrations row with a token, fetches up to 30 recent
 * events from GitHub and upserts them into github_events. Idempotent
 * per (user_id, github_id) so polls overlap without duplicating rows.
 *
 * Token storage:
 *   integrations.github_token is plain text today. When the user moves
 *   to Supabase Vault, replace the read in `loadToken()` only — every
 *   other call site is unaffected.
 */

import { createClient } from '@supabase/supabase-js';

const GH_BASE = 'https://api.github.com';

interface IntegrationRow {
  user_id: string;
  github_login: string;
  github_token: string;
}

interface GhEvent {
  id: string;
  type: string;
  repo: { name: string };
  payload: Record<string, unknown>;
  created_at: string;
}

Deno.serve(async (_req) => {
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return Response.json({ ok: false, error: 'missing_env' }, { status: 500 });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  const { data: integrations, error } = await supabase
    .from('integrations')
    .select('user_id, github_login, github_token')
    .not('github_token', 'is', null)
    .not('github_login', 'is', null);

  if (error) {
    return Response.json({ ok: false, error: error.message }, { status: 500 });
  }

  const results = await Promise.allSettled(
    (integrations as IntegrationRow[]).map((row) => pollOne(supabase, row)),
  );

  return Response.json({
    ok: true,
    integrations: integrations.length,
    succeeded: results.filter((r) => r.status === 'fulfilled').length,
    failed: results.filter((r) => r.status === 'rejected').length,
  });
});

async function pollOne(
  supabase: ReturnType<typeof createClient>,
  row: IntegrationRow,
): Promise<void> {
  try {
    const events = await fetchEvents(row.github_login, row.github_token);
    const rows = events
      .map((e) => mapEvent(row.user_id, e))
      .filter((r): r is NonNullable<typeof r> => r != null);

    if (rows.length > 0) {
      const { error } = await supabase
        .from('github_events')
        .upsert(rows, { onConflict: 'user_id,github_id', ignoreDuplicates: true });
      if (error) throw new Error(`upsert: ${error.message}`);
    }

    await supabase.from('integration_runs').insert({
      user_id: row.user_id,
      kind: 'github_poll',
      status: 'ok',
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await supabase.from('integration_runs').insert({
      user_id: row.user_id,
      kind: 'github_poll',
      status: 'error',
      error: msg,
    });
    throw e;
  }
}

async function fetchEvents(login: string, token: string): Promise<GhEvent[]> {
  const res = await fetch(`${GH_BASE}/users/${encodeURIComponent(login)}/events?per_page=30`, {
    headers: {
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      Authorization: `Bearer ${token}`,
      'User-Agent': 'memoir-log/1.0',
    },
    signal: AbortSignal.timeout(15_000),
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`github ${res.status}: ${text.slice(0, 200)}`);
  }
  return await res.json() as GhEvent[];
}

function mapEvent(userId: string, e: GhEvent): {
  user_id: string;
  github_id: string;
  local_date: string;
  event_type: string;
  repo: string;
  commits: number;
  payload: Record<string, unknown>;
  occurred_at: string;
} | null {
  const occurred = new Date(e.created_at);
  // Local date assumed UTC-equivalent here; the daily-summary function
  // re-computes with the user's timezone when aggregating.
  const local_date = e.created_at.slice(0, 10);

  switch (e.type) {
    case 'PushEvent': {
      const commits = (e.payload?.commits as unknown[] | undefined)?.length ?? 0;
      return {
        user_id: userId,
        github_id: e.id,
        local_date,
        event_type: 'push',
        repo: e.repo.name,
        commits,
        payload: e.payload,
        occurred_at: occurred.toISOString(),
      };
    }
    case 'PullRequestEvent': {
      const action = e.payload?.action as string | undefined;
      const merged = (e.payload?.pull_request as { merged?: boolean } | undefined)?.merged === true;
      const event_type = merged ? 'pr_merged' : (action === 'opened' ? 'pr_opened' : null);
      if (event_type == null) return null;
      return {
        user_id: userId,
        github_id: e.id,
        local_date,
        event_type,
        repo: e.repo.name,
        commits: 0,
        payload: e.payload,
        occurred_at: occurred.toISOString(),
      };
    }
    case 'IssuesEvent': {
      const action = e.payload?.action as string | undefined;
      const event_type = action === 'opened' ? 'issue_opened'
        : action === 'closed' ? 'issue_closed'
        : null;
      if (event_type == null) return null;
      return {
        user_id: userId,
        github_id: e.id,
        local_date,
        event_type,
        repo: e.repo.name,
        commits: 0,
        payload: e.payload,
        occurred_at: occurred.toISOString(),
      };
    }
    default:
      return null;
  }
}
