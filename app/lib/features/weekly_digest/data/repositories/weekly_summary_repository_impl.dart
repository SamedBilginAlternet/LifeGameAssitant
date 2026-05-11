import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/weekly_digest/data/datasources/weekly_summary_remote_data_source.dart';
import 'package:memoir_log/features/weekly_digest/domain/entities/weekly_summary.dart';
import 'package:memoir_log/features/weekly_digest/domain/repositories/weekly_summary_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WeeklySummaryRepositoryImpl implements WeeklySummaryRepository {
  WeeklySummaryRepositoryImpl({
    required WeeklySummaryRemoteDataSource remote,
    required String Function() currentUserId,
  }) : _remote = remote,
       _currentUserId = currentUserId;

  final WeeklySummaryRemoteDataSource _remote;
  final String Function() _currentUserId;

  Failure _classify(Object e) {
    if (e is PostgrestException) return ServerFailure(e.message);
    if (e is SocketException) return const NetworkFailure('offline');
    return UnknownFailure(e.toString());
  }

  @override
  Future<Either<Failure, List<WeeklySummary>>> recent({int limit = 8}) async {
    try {
      final rows = await _remote.recent(userId: _currentUserId(), limit: limit);
      return Right(rows.map(_fromRow).toList());
    } catch (e) {
      return Left(_classify(e));
    }
  }

  WeeklySummary _fromRow(Map<String, dynamic> row) {
    return WeeklySummary(
      weekStartDate: DateTime.parse(row['week_start_date'] as String),
      weekEndDate: DateTime.parse(row['week_end_date'] as String),
      status: _statusFrom(row['status'] as String?),
      body: row['body'] as String?,
      topSkill: row['top_skill'] as String?,
      error: row['error'] as String?,
    );
  }

  WeeklySummaryStatus _statusFrom(String? raw) => switch (raw) {
    'ok' => WeeklySummaryStatus.ok,
    'empty' => WeeklySummaryStatus.empty,
    'failed' => WeeklySummaryStatus.failed,
    _ => WeeklySummaryStatus.pending,
  };
}
