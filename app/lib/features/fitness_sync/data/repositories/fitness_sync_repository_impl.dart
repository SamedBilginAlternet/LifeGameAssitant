import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/fitness_sync/data/datasources/fitness_sync_remote_data_source.dart';
import 'package:memoir_log/features/fitness_sync/data/datasources/health_data_source.dart';
import 'package:memoir_log/features/fitness_sync/domain/repositories/fitness_sync_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FitnessSyncRepositoryImpl implements FitnessSyncRepository {
  FitnessSyncRepositoryImpl({
    required HealthDataSource health,
    required FitnessSyncRemoteDataSource remote,
    required String Function() currentUserId,
  }) : _health = health,
       _remote = remote,
       _currentUserId = currentUserId;

  final HealthDataSource _health;
  final FitnessSyncRemoteDataSource _remote;
  final String Function() _currentUserId;

  Failure _classify(Object e) {
    if (e is PostgrestException) return ServerFailure(e.message);
    if (e is SocketException) return const NetworkFailure('offline');
    return UnknownFailure(e.toString());
  }

  /// `health` only supports mobile. Bail early on web/desktop so we
  /// don't surface 'plugin unimplemented' errors at the UI layer.
  bool get _platformSupported => !kIsWebOrDesktop;

  String _sourceTag() => Platform.isIOS ? 'healthkit' : 'health_connect';

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Either<Failure, bool>> requestPermissions() async {
    if (!_platformSupported) return const Right(false);
    try {
      return Right(await _health.requestPermissions());
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, void>> syncToday() async {
    if (!_platformSupported) return const Right(null);
    try {
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final iso = _isoDate(now);
      final source = _sourceTag();
      final userId = _currentUserId();

      final steps = await _health.stepsBetween(start, now);
      if (steps != null && steps > 0) {
        await _remote.upsert(
          userId: userId,
          localDate: iso,
          metric: 'steps',
          value: steps,
          source: source,
        );
      }

      final kcal = await _health.activeKcalBetween(start, now);
      if (kcal != null && kcal > 0) {
        await _remote.upsert(
          userId: userId,
          localDate: iso,
          metric: 'calories',
          value: kcal,
          source: source,
        );
      }

      return const Right(null);
    } catch (e) {
      return Left(_classify(e));
    }
  }
}

/// True on web and desktop platforms where the `health` plugin is a
/// no-op. We avoid importing `package:flutter/foundation.dart`'s
/// `kIsWeb` here because that constant doesn't tell us about Linux/
/// macOS/Windows — `Platform.isIOS || Platform.isAndroid` does, but
/// reading Platform on web throws, so we check both fronts.
bool get kIsWebOrDesktop {
  try {
    return !(Platform.isIOS || Platform.isAndroid);
  } catch (_) {
    // Platform.isX throws on web — that's a web environment.
    return true;
  }
}
