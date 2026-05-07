import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/capture/data/datasources/capture_remote_data_source.dart';
import 'package:memoir_log/features/capture/data/repositories/capture_repository_impl.dart';
import 'package:memoir_log/features/capture/domain/repositories/capture_repository.dart';

final captureRemoteDataSourceProvider = Provider<CaptureRemoteDataSource>((ref) {
  return CaptureRemoteDataSource(ref.read(supabaseClientProvider));
});

final captureRepositoryProvider = Provider<CaptureRepository>((ref) {
  return CaptureRepositoryImpl(
    remote: ref.read(captureRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});
