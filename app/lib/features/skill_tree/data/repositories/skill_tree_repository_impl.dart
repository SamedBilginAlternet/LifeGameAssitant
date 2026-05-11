import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/skill_tree/data/datasources/skill_tree_remote_data_source.dart';
import 'package:memoir_log/features/skill_tree/domain/entities/skill.dart';
import 'package:memoir_log/features/skill_tree/domain/repositories/skill_tree_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SkillTreeRepositoryImpl implements SkillTreeRepository {
  SkillTreeRepositoryImpl({
    required SkillTreeRemoteDataSource remote,
    required String Function() currentUserId,
  }) : _remote = remote,
       _currentUserId = currentUserId;

  final SkillTreeRemoteDataSource _remote;
  final String Function() _currentUserId;

  Failure _classify(Object e) {
    if (e is PostgrestException) return ServerFailure(e.message);
    if (e is SocketException) return const NetworkFailure('offline');
    return UnknownFailure(e.toString());
  }

  @override
  Future<Either<Failure, SkillTreeSnapshot>> snapshot() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 30));
      final activity = await _remote.activitySince(
        userId: _currentUserId(),
        sinceDate: since,
      );
      final entryCounts = await _remote.entryTopSkillCounts(
        userId: _currentUserId(),
        sinceDate: since,
      );

      // Per-skill XP weights: pick numbers that make a single intense
      // burst feel rewarding without letting one source dominate the
      // tree. Tweak in flight if any skill consistently overshoots.
      final logicXp = (activity['github_events'] ?? 0) * 2;
      final vitalityXp =
          (activity['workouts'] ?? 0) * 8 +
          (activity['motorcycle_rides'] ?? 0) * 4;
      final linguisticsXp =
          (activity['german_minutes'] ?? 0) +
          (activity['voice_notes'] ?? 0) * 8;
      final cultureXp =
          (activity['movies_watched'] ?? 0) * 10 +
          ((activity['music_listens'] ?? 0) ~/ 3);
      final academicXp =
          (activity['research_minutes'] ?? 0) +
          (activity['reading_minutes'] ?? 0);

      final stats = [
        SkillStats(
          skill: Skill.logic,
          activityXp: logicXp,
          entryBonus: entryCounts['logic'] ?? 0,
        ),
        SkillStats(
          skill: Skill.vitality,
          activityXp: vitalityXp,
          entryBonus: entryCounts['vitality'] ?? 0,
        ),
        SkillStats(
          skill: Skill.linguistics,
          activityXp: linguisticsXp,
          entryBonus: entryCounts['linguistics'] ?? 0,
        ),
        SkillStats(
          skill: Skill.culture,
          activityXp: cultureXp,
          entryBonus: entryCounts['culture'] ?? 0,
        ),
        SkillStats(
          skill: Skill.academic,
          activityXp: academicXp,
          entryBonus: entryCounts['academic'] ?? 0,
        ),
      ];

      final dominant = stats
          .reduce((a, b) => a.totalXp >= b.totalXp ? a : b)
          .skill;
      return Right(SkillTreeSnapshot(stats: stats, dominant: dominant));
    } catch (e) {
      return Left(_classify(e));
    }
  }
}
