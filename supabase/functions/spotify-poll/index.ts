/**
 * spotify-poll — runs every 30 minutes via pg_cron.
 *
 * For every integrations row with a Spotify refresh token:
 *   1. Refresh the access token (PKCE refresh flow).
 *   2. Fetch /me/player/recently-played?limit=50.
 *   3. Upsert each play into music_listens (deduped on track_id +
 *      played_at).
 *
 * Env required:
 *   SPOTIFY_CLIENT_ID  — public client id from the Spotify dashboard.
 *
 * No client secret needed — PKCE is used by the mobile app for the
 * initial exchange, and Spotify accepts client_id-only refresh.
 */

import { createClient } from '@supabase/supabase-js';

interface IntegrationRow {
  user_id: string;
  spotify_refresh_token: string;
}

interface RecentlyPlayedItem {
  track: {
    id: string;
    name: string;
    duration_ms: number;
    artists: Array<{ name: string }>;
    album: { name: string };
  };
  played_at: string;
}

Deno.serve(async (_req) => {
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const CLIENT_ID = Deno.env.get('SPOTIFY_CLIENT_ID');

  if (!SUPABASE_URL || !SERVICE_ROLE || !CLIENT_ID) {
    return Response.json({ ok: false, error: 'missing_env' }, { status: 500 });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE);

  const { data: integrations, error } = await supabase
    .from('integrations')
    .select('user_id, spotify_refresh_token')
    .not('spotify_refresh_token', 'is', null);

  if (error) {
    return Response.json({ ok: false, error: error.message }, { status: 500 });
  }

  const results = await Promise.allSettled(
    (integrations as IntegrationRow[]).map((row) =>
      pollOne(supabase, CLIENT_ID, row),
    ),
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
  clientId: string,
  row: IntegrationRow,
): Promise<void> {
  try {
    const access = await refreshAccessToken(clientId, row.spotify_refresh_token);
    const items = await fetchRecentlyPlayed(access.access_token);

    const rows = items.map((it) => mapItem(row.user_id, it));
    if (rows.length > 0) {
      const { error } = await supabase
        .from('music_listens')
        .upsert(rows, {
          onConflict: 'user_id,source,track_id,played_at',
          ignoreDuplicates: true,
        });
      if (error) throw new Error(`upsert: ${error.message}`);
    }

    // If Spotify rotated the refresh token, persist the new one.
    if (access.refresh_token && access.refresh_token !== row.spotify_refresh_token) {
      await supabase
        .from('integrations')
        .update({ spotify_refresh_token: access.refresh_token })
        .eq('user_id', row.user_id);
    }

    await supabase
      .from('integrations')
      .update({ spotify_last_polled: new Date().toISOString() })
      .eq('user_id', row.user_id);

    await supabase.from('integration_runs').insert({
      user_id: row.user_id,
      kind: 'spotify_poll',
      status: 'ok',
    });
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    await supabase.from('integration_runs').insert({
      user_id: row.user_id,
      kind: 'spotify_poll',
      status: 'error',
      error: msg,
    });
    throw e;
  }
}

async function refreshAccessToken(
  clientId: string,
  refreshToken: string,
): Promise<{ access_token: string; refresh_token?: string; expires_in: number }> {
  const body = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
    client_id: clientId,
  });
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) {
    throw new Error(`spotify token refresh ${res.status}: ${await res.text()}`);
  }
  return await res.json();
}

async function fetchRecentlyPlayed(accessToken: string): Promise<RecentlyPlayedItem[]> {
  const res = await fetch(
    'https://api.spotify.com/v1/me/player/recently-played?limit=50',
    {
      headers: { Authorization: `Bearer ${accessToken}` },
      signal: AbortSignal.timeout(15_000),
    },
  );
  if (res.status === 204) return [];
  if (!res.ok) {
    throw new Error(`spotify recently-played ${res.status}: ${await res.text()}`);
  }
  const json = await res.json();
  return (json.items as RecentlyPlayedItem[]) ?? [];
}

function mapItem(userId: string, it: RecentlyPlayedItem): {
  user_id: string;
  local_date: string;
  source: string;
  track_id: string;
  track_title: string;
  artist: string;
  album: string;
  duration_sec: number;
  played_at: string;
} {
  return {
    user_id: userId,
    local_date: it.played_at.slice(0, 10),
    source: 'spotify',
    track_id: it.track.id,
    track_title: it.track.name,
    artist: it.track.artists.map((a) => a.name).join(', '),
    album: it.track.album.name,
    duration_sec: Math.round(it.track.duration_ms / 1000),
    played_at: it.played_at,
  };
}
