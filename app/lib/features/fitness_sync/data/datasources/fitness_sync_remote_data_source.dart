import 'package:supabase_flutter/supabase_flutter.dart';

/// Writes to the same fitness_data table as the manual capture flow,
/// but tags rows with source='healthkit' or 'health_connect' instead of
/// 'manual' so the user (or a future Settings → History view) can
/// distinguish auto-captured rows.
class FitnessSyncRemoteDataSource {
  FitnessSyncRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<void> upsert({
    required String userId,
    required String localDate,
    required String metric,
    required num value,
    required String source,
  }) async {
    await _client.from('fitness_data').upsert({
      'user_id': userId,
      'local_date': localDate,
      'metric': metric,
      'value': value,
      'source': source,
    }, onConflict: 'user_id,local_date,metric');
  }
}
