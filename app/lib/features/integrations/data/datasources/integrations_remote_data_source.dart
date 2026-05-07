import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IntegrationsRemoteDataSource {
  IntegrationsRemoteDataSource(this._client, {Dio? dio})
      : _dio = dio ?? Dio();

  final SupabaseClient _client;
  final Dio _dio;

  // ── GitHub ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> readGithub({required String userId}) async {
    return await _client
        .from('integrations')
        .select('github_token, github_login')
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<void> upsertGithub({
    required String userId,
    required String token,
    required String login,
  }) async {
    await _client.from('integrations').upsert({
      'user_id': userId,
      'github_token': token,
      'github_login': login,
    });
  }

  Future<void> deleteGithub({required String userId}) async {
    await _client.from('integrations').delete().eq('user_id', userId);
  }

  /// Calls GitHub /user with the candidate token. Returns the login
  /// on a 200, throws on anything else so the repository can convert
  /// to AuthFailure.
  Future<String> validateGithubToken(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      'https://api.github.com/user',
      options: Options(
        headers: {
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $token',
          'User-Agent': 'memoir-log/1.0',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    if (res.statusCode != 200) {
      throw FormatException('github returned ${res.statusCode}');
    }
    final login = res.data?['login'] as String?;
    if (login == null || login.isEmpty) {
      throw const FormatException('github returned no login');
    }
    return login;
  }

  // ── Spotify ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> readSpotify({required String userId}) async {
    return await _client
        .from('integrations')
        .select(
          'spotify_refresh_token, spotify_user_id, spotify_last_polled',
        )
        .eq('user_id', userId)
        .maybeSingle();
  }

  /// Posts the auth code + verifier to the spotify-token-exchange Edge
  /// Function. The function exchanges the code with Spotify, fetches
  /// /me, and upserts the integrations row server-side. Returns the
  /// resulting `spotify_user_id`.
  Future<String> exchangeSpotifyCode({
    required String code,
    required String codeVerifier,
    required String redirectUri,
  }) async {
    final res = await _client.functions.invoke(
      'spotify-token-exchange',
      body: {
        'code': code,
        'code_verifier': codeVerifier,
        'redirect_uri': redirectUri,
      },
    );
    final data = res.data;
    if (data is! Map) {
      throw const FormatException('spotify-token-exchange returned no body');
    }
    final ok = data['ok'] == true;
    if (!ok) {
      final err = data['error']?.toString() ?? 'unknown';
      throw FormatException('spotify-token-exchange failed: $err');
    }
    final userId = data['spotify_user_id']?.toString();
    if (userId == null || userId.isEmpty) {
      throw const FormatException('spotify-token-exchange returned no user id');
    }
    return userId;
  }

  Future<void> clearSpotify({required String userId}) async {
    await _client.from('integrations').update({
      'spotify_refresh_token': null,
      'spotify_user_id': null,
      'spotify_last_polled': null,
    }).eq('user_id', userId);
  }

  // ── Health ─────────────────────────────────────────────────────────

  /// Returns the most recent integration_runs row per kind for the
  /// given user. The repository converts these into
  /// IntegrationHealthStatus values.
  Future<List<Map<String, dynamic>>> latestRuns({required String userId}) async {
    // No `distinct on` in supabase_dart yet, so pull a small window
    // (last ~24h, capped at 50 rows) and reduce client-side. Cheaper
    // than a full table scan and accurate enough for "latest run".
    final since = DateTime.now()
        .subtract(const Duration(hours: 24))
        .toUtc()
        .toIso8601String();
    final rows = await _client
        .from('integration_runs')
        .select('kind, status, error, ran_at')
        .eq('user_id', userId)
        .gte('ran_at', since)
        .order('ran_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows as List<dynamic>);
  }
}
