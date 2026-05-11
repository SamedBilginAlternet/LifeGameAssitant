import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceNotesRemoteDataSource {
  VoiceNotesRemoteDataSource(this._client);

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> readNote({
    required String userId,
    required String localDate,
  }) async {
    return await _client
        .from('voice_notes')
        .select(
          'id, storage_path, duration_sec, language, transcript_de, '
          'transcript_en, corrections, status, error',
        )
        .eq('user_id', userId)
        .eq('local_date', localDate)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> upsertNote({
    required String userId,
    required String localDate,
    required String storagePath,
    required int durationSec,
  }) async {
    final res = await _client
        .from('voice_notes')
        .upsert({
          'user_id': userId,
          'local_date': localDate,
          'storage_path': storagePath,
          'duration_sec': durationSec,
          'status': 'pending',
          'language': null,
          'transcript_de': null,
          'transcript_en': null,
          'corrections': null,
          'error': null,
          'processed_at': null,
        }, onConflict: 'user_id,local_date')
        .select()
        .single();
    return res;
  }

  Future<void> uploadAudio({
    required String storagePath,
    required Uint8List bytes,
  }) async {
    await _client.storage
        .from('voice')
        .uploadBinary(
          storagePath,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'audio/mp4',
            upsert: true,
          ),
        );
  }

  /// Fires the voice-transcribe Edge Function. The function is
  /// idempotent so a duplicate call (e.g. retry on network error) is
  /// safe.
  Future<void> triggerTranscribe(String voiceNoteId) async {
    await _client.functions.invoke(
      'voice-transcribe',
      body: {'voice_note_id': voiceNoteId},
    );
  }

  Future<String> signedAudioUrl(String storagePath) async {
    return await _client.storage
        .from('voice')
        .createSignedUrl(storagePath, 600);
  }
}
