import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/weekly_digest/domain/entities/weekly_summary.dart';

abstract class WeeklySummaryRepository {
  /// Returns the most recent N weekly summaries for the signed-in user,
  /// newest first.
  Future<Either<Failure, List<WeeklySummary>>> recent({int limit = 8});
}
