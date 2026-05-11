import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklySummaryRemoteDataSource {
  WeeklySummaryRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> recent({
    required String userId,
    required int limit,
  }) async {
    final rows = await _client
        .from('weekly_summaries')
        .select(
          'week_start_date, week_end_date, body, top_skill, status, error',
        )
        .eq('user_id', userId)
        .order('week_start_date', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows as List<dynamic>);
  }
}
