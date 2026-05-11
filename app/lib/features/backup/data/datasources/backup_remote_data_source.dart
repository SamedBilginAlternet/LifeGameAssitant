import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads every user-scoped table by `user_id`. RLS guarantees the user
/// only sees their own rows even though we don't double-filter here.
class BackupRemoteDataSource {
  BackupRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Tables to include in the export. Order matters only for
  /// readability of the resulting JSON; all are dumped in full.
  static const _tables = <String>[
    'profiles',
    'daily_logs',
    'fitness_data',
    'learning_logs',
    'github_events',
    'workouts',
    'workout_sets',
    'meals',
    'movies_watched',
    'motorcycle_rides',
    'music_listens',
    'media_assets',
    'voice_notes',
    'entries',
    'integrations',
    'integration_runs',
  ];

  Future<Map<String, List<dynamic>>> dumpAll({required String userId}) async {
    final out = <String, List<dynamic>>{};
    for (final table in _tables) {
      final rows = await _client.from(table).select().eq('user_id', userId);
      out[table] = rows as List<dynamic>;
    }
    return out;
  }
}
