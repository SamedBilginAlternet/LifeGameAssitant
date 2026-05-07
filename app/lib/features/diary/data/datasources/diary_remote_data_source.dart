import 'package:memoir_log/features/diary/data/dtos/entry_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class DiaryRemoteDataSource {
  Future<List<EntryDto>> recentEntries({required String userId, int limit = 60});
  Future<EntryDto?> entryFor({required String userId, required String localDate});
  Stream<List<EntryDto>> streamEntries({required String userId, int limit = 60});
  Future<void> invokeResummarize({required String userId, required String localDate});
}

class DiaryRemoteDataSourceImpl implements DiaryRemoteDataSource {
  DiaryRemoteDataSourceImpl(this._client);
  final SupabaseClient _client;

  @override
  Future<List<EntryDto>> recentEntries({required String userId, int limit = 60}) async {
    final rows = await _client
        .from('entries')
        .select()
        .eq('user_id', userId)
        .order('local_date', ascending: false)
        .limit(limit);
    return rows.map((r) => EntryDto.fromJson(r)).toList();
  }

  @override
  Future<EntryDto?> entryFor({required String userId, required String localDate}) async {
    final row = await _client
        .from('entries')
        .select()
        .eq('user_id', userId)
        .eq('local_date', localDate)
        .maybeSingle();
    return row == null ? null : EntryDto.fromJson(row);
  }

  @override
  Stream<List<EntryDto>> streamEntries({required String userId, int limit = 60}) {
    // Realtime stream filtered by user_id and ordered by local_date desc.
    return _client
        .from('entries')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('local_date', ascending: false)
        .limit(limit)
        .map((rows) => rows.map((r) => EntryDto.fromJson(r)).toList());
  }

  @override
  Future<void> invokeResummarize({required String userId, required String localDate}) async {
    await _client.functions.invoke(
      'daily-summary',
      body: {'mode': 'user', 'user_id': userId, 'date': localDate},
    );
  }
}
