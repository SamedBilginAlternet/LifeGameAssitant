import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class CoverPhotoRemoteDataSource {
  CoverPhotoRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Returns the existing cover row for the given user/day, or null.
  Future<Map<String, dynamic>?> readCover({
    required String userId,
    required String localDate,
  }) async {
    return await _client
        .from('media_assets')
        .select('storage_path, dominant_hex, width, height')
        .eq('user_id', userId)
        .eq('kind', 'cover')
        .eq('local_date', localDate)
        .maybeSingle();
  }

  /// Uploads the bytes to `covers/<userId>/<localDate>.jpg` (overwrite
  /// allowed), then upserts the matching media_assets row.
  Future<String> uploadCover({
    required String userId,
    required String localDate,
    required Uint8List bytes,
    int? width,
    int? height,
    String? dominantHex,
  }) async {
    final path = '$userId/$localDate.jpg';
    await _client.storage.from('covers').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );

    await _client.from('media_assets').upsert({
      'user_id': userId,
      'local_date': localDate,
      'kind': 'cover',
      'source': 'user_upload',
      'storage_path': path,
      'width': width,
      'height': height,
      'dominant_hex': dominantHex,
    }, onConflict: 'user_id,local_date');

    return path;
  }

  Future<void> deleteCover({
    required String userId,
    required String localDate,
  }) async {
    final path = '$userId/$localDate.jpg';
    await _client.storage.from('covers').remove([path]);
    await _client
        .from('media_assets')
        .delete()
        .eq('user_id', userId)
        .eq('kind', 'cover')
        .eq('local_date', localDate);
  }

  /// Signed URLs are short-lived (10 min) — render-side only.
  Future<String> signedUrl(String storagePath) async {
    return await _client.storage
        .from('covers')
        .createSignedUrl(storagePath, 600);
  }
}
