import 'dart:typed_data';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/cover_photo/domain/entities/cover_photo.dart';

abstract class CoverPhotoRepository {
  /// Returns the cover photo for the given local day, or null if none.
  Future<Either<Failure, CoverPhoto?>> coverFor(DateTime localDate);

  /// Compresses [bytes] to JPEG and uploads to the `covers/` bucket
  /// under `<userId>/<localDate>.jpg`, then upserts the matching
  /// media_assets row. The unique constraint on (user_id, local_date)
  /// where kind='cover' guarantees one cover per day per user.
  Future<Either<Failure, CoverPhoto>> attach({
    required DateTime localDate,
    required Uint8List bytes,
  });

  /// Removes both the storage object and the media_assets row.
  Future<Either<Failure, void>> detach(DateTime localDate);

  /// Returns a short-lived signed URL for rendering the storage object.
  /// The covers bucket is private; raw URLs do not authenticate.
  Future<Either<Failure, String>> signedUrl(String storagePath);
}
