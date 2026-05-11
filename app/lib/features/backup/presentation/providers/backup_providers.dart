import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/backup/data/datasources/backup_remote_data_source.dart';
import 'package:memoir_log/features/backup/data/repositories/backup_repository_impl.dart';
import 'package:memoir_log/features/backup/domain/repositories/backup_repository.dart';

final backupRemoteDataSourceProvider = Provider<BackupRemoteDataSource>((ref) {
  return BackupRemoteDataSource(ref.read(supabaseClientProvider));
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepositoryImpl(
    remote: ref.read(backupRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});
