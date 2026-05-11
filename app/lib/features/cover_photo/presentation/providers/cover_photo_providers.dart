import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/cover_photo/data/datasources/cover_photo_remote_data_source.dart';
import 'package:memoir_log/features/cover_photo/data/repositories/cover_photo_repository_impl.dart';
import 'package:memoir_log/features/cover_photo/domain/entities/cover_photo.dart';
import 'package:memoir_log/features/cover_photo/domain/repositories/cover_photo_repository.dart';

final coverPhotoRemoteDataSourceProvider = Provider<CoverPhotoRemoteDataSource>(
  (ref) {
    return CoverPhotoRemoteDataSource(ref.read(supabaseClientProvider));
  },
);

final coverPhotoRepositoryProvider = Provider<CoverPhotoRepository>((ref) {
  return CoverPhotoRepositoryImpl(
    remote: ref.read(coverPhotoRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});

/// Family keyed by ISO local date. The chip on the diary page watches
/// the date that page renders, so swiping to another day re-fetches.
final coverPhotoForDateProvider =
    FutureProvider.family<Either<Failure, CoverPhoto?>, DateTime>((
      ref,
      date,
    ) async {
      return ref.read(coverPhotoRepositoryProvider).coverFor(date);
    });
