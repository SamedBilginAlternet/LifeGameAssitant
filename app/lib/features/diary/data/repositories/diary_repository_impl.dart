import 'dart:async';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/features/diary/data/datasources/diary_remote_data_source.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
import 'package:memoir_log/features/diary/domain/failures/diary_failure.dart';
import 'package:memoir_log/features/diary/domain/repositories/diary_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DiaryRepositoryImpl implements DiaryRepository {
  DiaryRepositoryImpl({
    required DiaryRemoteDataSource remote,
    required String Function() currentUserId,
  }) : _remote = remote,
       _currentUserId = currentUserId;

  final DiaryRemoteDataSource _remote;
  final String Function() _currentUserId;

  @override
  Future<Either<DiaryFailure, List<Entry>>> recentEntries({
    int limit = 60,
  }) async {
    try {
      final dtos = await _remote.recentEntries(
        userId: _currentUserId(),
        limit: limit,
      );
      return Right(dtos.map((d) => d.toEntity()).toList());
    } on PostgrestException catch (e) {
      return Left(DiaryServerFailure(e.message));
    } on SocketException {
      return const Left(DiaryNetworkFailure('offline'));
    } catch (e) {
      return Left(DiaryUnknownFailure(e.toString()));
    }
  }

  @override
  Future<Either<DiaryFailure, Entry>> todayEntry(DateTime localDate) async {
    final iso = _isoDate(localDate);
    try {
      final dto = await _remote.entryFor(
        userId: _currentUserId(),
        localDate: iso,
      );
      if (dto == null) return const Left(DiaryNotFound());
      return Right(dto.toEntity());
    } on PostgrestException catch (e) {
      return Left(DiaryServerFailure(e.message));
    } on SocketException {
      return const Left(DiaryNetworkFailure('offline'));
    } catch (e) {
      return Left(DiaryUnknownFailure(e.toString()));
    }
  }

  @override
  Stream<Either<DiaryFailure, List<Entry>>> watchEntries({
    int limit = 60,
  }) async* {
    final userId = _currentUserId();
    final source = _remote.streamEntries(userId: userId, limit: limit);
    yield* source
        .map<Either<DiaryFailure, List<Entry>>>(
          (dtos) => Right(dtos.map((d) => d.toEntity()).toList()),
        )
        .handleError((Object error) {
          if (error is SocketException) {
            return const Left(DiaryNetworkFailure('offline'));
          }
          return Left(DiaryUnknownFailure(error.toString()));
        });
  }

  @override
  Future<Either<DiaryFailure, void>> resummarize(DateTime localDate) async {
    try {
      await _remote.invokeResummarize(
        userId: _currentUserId(),
        localDate: _isoDate(localDate),
      );
      return const Right(null);
    } on FunctionException catch (e) {
      return Left(DiaryServerFailure(e.toString()));
    } on SocketException {
      return const Left(DiaryNetworkFailure('offline'));
    } catch (e) {
      return Left(DiaryUnknownFailure(e.toString()));
    }
  }

  String _isoDate(DateTime d) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${pad(d.month)}-${pad(d.day)}';
  }
}
