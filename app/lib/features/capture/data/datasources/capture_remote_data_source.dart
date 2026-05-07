import 'package:supabase_flutter/supabase_flutter.dart';

class CaptureRemoteDataSource {
  CaptureRemoteDataSource(this._client);
  final SupabaseClient _client;

  Future<void> upsertDailyLog({
    required String userId,
    required String localDate,
    int? moodScore,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'local_date': localDate,
      if (moodScore != null) 'mood_score': moodScore,
      if (note != null) 'note': note,
    };
    await _client
        .from('daily_logs')
        .upsert(payload, onConflict: 'user_id,local_date');
  }

  Future<void> upsertFitness({
    required String userId,
    required String localDate,
    required String metric,
    required num value,
  }) async {
    await _client.from('fitness_data').upsert({
      'user_id': userId,
      'local_date': localDate,
      'metric': metric,
      'value': value,
      'source': 'manual',
    }, onConflict: 'user_id,local_date,metric');
  }

  Future<void> insertLearning({
    required String userId,
    required String localDate,
    required String track,
    required int minutes,
    String? topic,
  }) async {
    await _client.from('learning_logs').insert({
      'user_id': userId,
      'local_date': localDate,
      'track': track,
      'minutes': minutes,
      if (topic != null && topic.isNotEmpty) 'topic': topic,
    });
  }
}
