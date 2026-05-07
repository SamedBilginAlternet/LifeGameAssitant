import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/features/diary/domain/failures/diary_failure.dart';
import 'package:memoir_log/features/diary/domain/repositories/diary_repository.dart';

/// Triggers a re-run of the daily-summary Edge Function for today's
/// date. Bound to pull-to-refresh on the timeline.
class ResummarizeToday {
  const ResummarizeToday(this._repo);
  final DiaryRepository _repo;

  Future<Either<DiaryFailure, void>> call() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _repo.resummarize(today);
  }
}
