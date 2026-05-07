import 'package:supabase_flutter/supabase_flutter.dart';

/// All counts here are constrained to the rolling 30-day window so the
/// XP score reflects current activity rather than an all-time high
/// the user has long since drifted away from.
class SkillTreeRemoteDataSource {
  SkillTreeRemoteDataSource(this._client);

  final SupabaseClient _client;

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Returns counts for every source that feeds the XP calculation,
  /// keyed by stable string ids the repository understands.
  Future<Map<String, int>> activitySince({
    required String userId,
    required DateTime sinceDate,
  }) async {
    final iso = _isoDate(sinceDate);
    final results = await Future.wait([
      _count('github_events', userId, iso),
      _count('workouts', userId, iso),
      _count('motorcycle_rides', userId, iso),
      _count('movies_watched', userId, iso),
      _count('music_listens', userId, iso),
      _count('voice_notes', userId, iso),
      _learningMinutes(userId, iso, 'german'),
      _learningMinutes(userId, iso, 'research'),
      _learningMinutes(userId, iso, 'reading'),
    ]);
    return {
      'github_events': results[0],
      'workouts': results[1],
      'motorcycle_rides': results[2],
      'movies_watched': results[3],
      'music_listens': results[4],
      'voice_notes': results[5],
      'german_minutes': results[6],
      'research_minutes': results[7],
      'reading_minutes': results[8],
    };
  }

  Future<Map<String, int>> entryTopSkillCounts({
    required String userId,
    required DateTime sinceDate,
  }) async {
    final iso = _isoDate(sinceDate);
    final rows = await _client
        .from('entries')
        .select('top_skill')
        .eq('user_id', userId)
        .gte('local_date', iso)
        .not('top_skill', 'is', null);
    final out = <String, int>{};
    for (final row in rows as List<dynamic>) {
      final skill = (row as Map<String, dynamic>)['top_skill'] as String?;
      if (skill == null) continue;
      out[skill] = (out[skill] ?? 0) + 1;
    }
    return out;
  }

  Future<int> _count(String table, String userId, String sinceIso) async {
    final res = await _client
        .from(table)
        .select('user_id')
        .eq('user_id', userId)
        .gte('local_date', sinceIso)
        .count();
    return res.count;
  }

  Future<int> _learningMinutes(
    String userId,
    String sinceIso,
    String track,
  ) async {
    final rows = await _client
        .from('learning_logs')
        .select('minutes')
        .eq('user_id', userId)
        .eq('track', track)
        .gte('local_date', sinceIso);
    var total = 0;
    for (final row in rows as List<dynamic>) {
      final m = (row as Map<String, dynamic>)['minutes'];
      if (m is num) total += m.toInt();
    }
    return total;
  }
}
