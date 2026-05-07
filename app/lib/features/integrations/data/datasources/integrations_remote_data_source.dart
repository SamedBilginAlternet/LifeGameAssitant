import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IntegrationsRemoteDataSource {
  IntegrationsRemoteDataSource(this._client, {Dio? dio})
      : _dio = dio ?? Dio();

  final SupabaseClient _client;
  final Dio _dio;

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
}
