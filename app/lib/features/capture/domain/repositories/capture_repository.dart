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

  /// Inserts a meals row.
  Future<Either<Failure, void>> logMeal({
    required String mealType,
    required String title,
    int? calories,
    num? proteinG,
    num? carbsG,
  });

  /// Inserts a movies_watched row.
  Future<Either<Failure, void>> logMovie({
    required String title,
    int? releaseYear,
    int? rating,
    String? medium,
  });

  /// Inserts a motorcycle_rides row.
  Future<Either<Failure, void>> logRide({
    required num distanceKm,
    int? durationMin,
    String? routeTag,
    String? notes,
  });

  /// Inserts a workouts row (sets are captured separately in Phase 4+).
  Future<Either<Failure, void>> logWorkout({
    required String name,
    int? durationMin,
    num? totalVolumeKg,
    String? notes,
  });
}
