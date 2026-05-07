import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/capture/data/datasources/capture_remote_data_source.dart';
import 'package:memoir_log/features/capture/domain/repositories/capture_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaptureRepositoryImpl implements CaptureRepository {
  CaptureRepositoryImpl({
    required CaptureRemoteDataSource remote,
    required String Function() currentUserId,
  })  : _remote = remote,
        _currentUserId = currentUserId;

  final CaptureRemoteDataSource _remote;
  final String Function() _currentUserId;

  String _today() {
    final n = DateTime.now();
    String pad(int x) => x.toString().padLeft(2, '0');
    return '${n.year}-${pad(n.month)}-${pad(n.day)}';
  }

  Future<Either<Failure, void>> _guard(Future<void> Function() body) async {
    try {
      await body();
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } on SocketException {
      return const Left(NetworkFailure('offline'));
    } catch (e) {
      return Left(UnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveMood({required int score}) {
    return _guard(() => _remote.upsertDailyLog(
          userId: _currentUserId(),
          localDate: _today(),
          moodScore: score,
        ));
  }

  @override
  Future<Either<Failure, void>> saveNote({required String note}) {
    return _guard(() => _remote.upsertDailyLog(
          userId: _currentUserId(),
          localDate: _today(),
          note: note,
        ));
  }

  @override
  Future<Either<Failure, void>> saveFitnessMetric({
    required String metric,
    required num value,
  }) {
    return _guard(() => _remote.upsertFitness(
          userId: _currentUserId(),
          localDate: _today(),
          metric: metric,
          value: value,
        ));
  }

  @override
  Future<Either<Failure, void>> logLearning({
    required String track,
    required int minutes,
    String? topic,
  }) {
    return _guard(() => _remote.insertLearning(
          userId: _currentUserId(),
          localDate: _today(),
          track: track,
          minutes: minutes,
          topic: topic,
        ));
  }
}
