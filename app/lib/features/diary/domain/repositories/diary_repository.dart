import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
import 'package:memoir_log/features/diary/domain/failures/diary_failure.dart';

/// The contract. The data layer implements it; the domain and
/// presentation layers depend only on this abstract type. Per the
/// CI grep in .github/workflows/ci.yml, no implementation imports
/// are allowed in this directory.
abstract class DiaryRepository {
  /// One-shot fetch of the most recent N entries for the user.
  Future<Either<DiaryFailure, List<Entry>>> recentEntries({int limit = 60});

  /// One-shot fetch of today's entry, if it exists. Resolves to a
  /// [DiaryNotFound] when the day hasn't been generated yet.
  Future<Either<DiaryFailure, Entry>> todayEntry(DateTime localDate);

  /// Streams the user's entries via Supabase Realtime. Each emission
  /// is the full sorted list — the timeline can render it directly
  /// without diff bookkeeping.
  Stream<Either<DiaryFailure, List<Entry>>> watchEntries({int limit = 60});

  /// Trigger a re-summarize for a specific day. Used by pull-to-refresh.
  Future<Either<DiaryFailure, void>> resummarize(DateTime localDate);
}
