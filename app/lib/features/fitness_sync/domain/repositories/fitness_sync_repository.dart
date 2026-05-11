import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';

abstract class FitnessSyncRepository {
  /// True once Apple HealthKit / Android Health Connect has been granted
  /// read access for steps + active energy.
  Future<Either<Failure, bool>> requestPermissions();

  /// Reads steps + active energy for today and upserts them into
  /// fitness_data with source='healthkit' or 'health_connect'. No-ops
  /// on platforms the health plugin doesn't support (web, desktop).
  Future<Either<Failure, void>> syncToday();
}
