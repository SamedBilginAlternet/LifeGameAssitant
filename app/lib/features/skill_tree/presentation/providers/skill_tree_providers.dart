import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/skill_tree/data/datasources/skill_tree_remote_data_source.dart';
import 'package:memoir_log/features/skill_tree/data/repositories/skill_tree_repository_impl.dart';
import 'package:memoir_log/features/skill_tree/domain/entities/skill.dart';
import 'package:memoir_log/features/skill_tree/domain/repositories/skill_tree_repository.dart';

final skillTreeRemoteDataSourceProvider = Provider<SkillTreeRemoteDataSource>((
  ref,
) {
  return SkillTreeRemoteDataSource(ref.read(supabaseClientProvider));
});

final skillTreeRepositoryProvider = Provider<SkillTreeRepository>((ref) {
  return SkillTreeRepositoryImpl(
    remote: ref.read(skillTreeRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});

final skillTreeSnapshotProvider =
    FutureProvider<Either<Failure, SkillTreeSnapshot>>((ref) async {
      return ref.read(skillTreeRepositoryProvider).snapshot();
    });
