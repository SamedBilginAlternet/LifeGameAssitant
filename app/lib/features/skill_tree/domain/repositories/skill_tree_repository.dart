import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/skill_tree/domain/entities/skill.dart';

abstract class SkillTreeRepository {
  /// Returns the rolling-30-day skill snapshot for the current user.
  Future<Either<Failure, SkillTreeSnapshot>> snapshot();
}
