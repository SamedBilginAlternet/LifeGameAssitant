import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/fitness_sync/data/datasources/fitness_sync_remote_data_source.dart';
import 'package:memoir_log/features/fitness_sync/data/datasources/health_data_source.dart';
import 'package:memoir_log/features/fitness_sync/data/repositories/fitness_sync_repository_impl.dart';
import 'package:memoir_log/features/fitness_sync/domain/repositories/fitness_sync_repository.dart';

final healthDataSourceProvider = Provider<HealthDataSource>((ref) {
  return HealthDataSource();
});

final fitnessSyncRemoteDataSourceProvider =
    Provider<FitnessSyncRemoteDataSource>((ref) {
      return FitnessSyncRemoteDataSource(ref.read(supabaseClientProvider));
    });

final fitnessSyncRepositoryProvider = Provider<FitnessSyncRepository>((ref) {
  return FitnessSyncRepositoryImpl(
    health: ref.read(healthDataSourceProvider),
    remote: ref.read(fitnessSyncRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});
