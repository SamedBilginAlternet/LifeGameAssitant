/**
 * spotify-token-exchange — completes the PKCE auth-code exchange after
 * the mobile app has obtained an authorization code from Spotify.
 *
 * Request:
 *   POST { code, code_verifier, redirect_uri }
 *   Authorization: Bearer <supabase user jwt>
 *
 * Behaviour:
 *   1. Resolve the calling user from the JWT.
 *   2. Exchange code + verifier with Spotify for a refresh + access pair.
 *   3. Use the access token to read /me for the Spotify user id.
 *   4. Upsert integrations row with refresh token + spotify_user_id.
 *   5. Return { ok, spotify_user_id }.
 *
 * Env required:
 *   SPOTIFY_CLIENT_ID — public client id from the Spotify dashboard.
 */

import { createClient } from '@supabase/supabase-js';

interface ExchangeBody {
  code?: string;
  code_verifier?: string;
  redirect_uri?: string;
}

interface SpotifyTokenResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  scope: string;
  token_type: string;
}

interface SpotifyMe {
  id: string;
  display_name?: string;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') {
    return Response.json({ ok: false, error: 'method_not_allowed' }, { status: 405 });
  }

  const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
  const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY');
  const CLIENT_ID = Deno.env.get('SPOTIFY_CLIENT_ID');

  if (!SUPABASE_URL || !SERVICE_ROLE || !ANON_KEY || !CLIENT_ID) {
    return Response.json({ ok: false, error: 'missing_env' }, { status: 500 });
  }

  // Resolve the calling user from the JWT in the Authorization header.
  const auth = req.headers.get('Authorization');
  if (!auth) {
    return Response.json({ ok: false, error: 'missing_auth' }, { status: 401 });
  }
  const userClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: auth } },
  });
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) {
    return Response.json({ ok: false, error: 'invalid_jwt' }, { status: 401 });
  }
  const userId = userData.user.id;

  let body: ExchangeBody;
  try {
    body = await req.json() as ExchangeBody;
  } catch {
    return Response.json({ ok: false, error: 'invalid_json' }, { status: 400 });
  }
  const { code, code_verifier: verifier, redirect_uri: redirectUri } = body;
  if (!code || !verifier || !redirectUri) {
    return Response.json({ ok: false, error: 'missing_fields' }, { status: 400 });
  }

  // Step 1: exchange code + verifier for tokens.
  let tokens: SpotifyTokenResponse;
  try {
    tokens = await exchangeCode(CLIENT_ID, code, verifier, redirectUri);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return Response.json({ ok: false, error: msg }, { status: 502 });
  }

  // Step 2: resolve the Spotify user id.
  let me: SpotifyMe;
  try {
    me = await fetchMe(tokens.access_token);
  } catch (e) {
    const msg = e instanceof Error ? e.message : String(e);
    return Response.json({ ok: false, error: msg }, { status: 502 });
  }

  // Step 3: persist via the service-role client so RLS doesn't get in
  // the way of the upsert when the integrations row already exists for
  // a different (e.g. github-only) provider.
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE);
  const { error: upsertErr } = await admin.from('integrations').upsert({
    user_id: userId,
    spotify_refresh_token: tokens.refresh_token,
    spotify_user_id: me.id,
    spotify_last_polled: null,
  }, { onConflict: 'user_id' });
  if (upsertErr) {
    return Response.json({ ok: false, error: upsertErr.message }, { status: 500 });
  }

  return Response.json({ ok: true, spotify_user_id: me.id });
});

async function exchangeCode(
  clientId: string,
  code: string,
  verifier: string,
  redirectUri: string,
): Promise<SpotifyTokenResponse> {
  const body = new URLSearchParams({
    grant_type: 'authorization_code',
    code,
    redirect_uri: redirectUri,
    client_id: clientId,
    code_verifier: verifier,
  });
  const res = await fetch('https://accounts.spotify.com/api/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) {
    throw new Error(`spotify code exchange ${res.status}: ${await res.text()}`);
  }
  return await res.json() as SpotifyTokenResponse;
}

async function fetchMe(accessToken: string): Promise<SpotifyMe> {
  const res = await fetch('https://api.spotify.com/v1/me', {
    headers: { Authorization: `Bearer ${accessToken}` },
    signal: AbortSignal.timeout(10_000),
  });
  if (!res.ok) {
    throw new Error(`spotify /me ${res.status}: ${await res.text()}`);
  }
  return await res.json() as SpotifyMe;
}
