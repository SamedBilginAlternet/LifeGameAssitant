import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
import 'package:memoir_log/features/diary/domain/failures/diary_failure.dart';
import 'package:memoir_log/features/diary/domain/repositories/diary_repository.dart';

/// Streams the user's entries for the timeline. Pure pass-through —
/// listed as a use case for testability + symmetry, not because there's
/// business logic worth extracting today. Per CODE_STANDARDS.md, this
/// is the kind of thin wrapper we keep when more logic is likely to
/// arrive (filtering by skill, hiding failed entries on a setting).
class WatchEntries {
  const WatchEntries(this._repo);
  final DiaryRepository _repo;

  Stream<Either<DiaryFailure, List<Entry>>> call({int limit = 60}) {
    return _repo.watchEntries(limit: limit);
  }
}
