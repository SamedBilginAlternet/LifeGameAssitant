import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';

/// Quick-add writes for the manual MVP. Each method handles a single
/// domain — the use cases compose them into screens.
abstract class CaptureRepository {
  /// Upserts the daily_logs row's mood_score for today.
  Future<Either<Failure, void>> saveMood({required int score});

  /// Optional free-text note appended to today's daily_logs row.
  Future<Either<Failure, void>> saveNote({required String note});

  /// Sets a fitness_data row for today (latest-write-wins on metric).
  Future<Either<Failure, void>> saveFitnessMetric({
    required String metric,
    required num value,
  });

  /// Inserts a learning_logs row.
  Future<Either<Failure, void>> logLearning({
    required String track,
    required int minutes,
    String? topic,
  });
}
