import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/integrations/data/datasources/integrations_remote_data_source.dart';
import 'package:memoir_log/features/integrations/domain/repositories/integrations_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IntegrationsRepositoryImpl implements IntegrationsRepository {
  IntegrationsRepositoryImpl({
    required IntegrationsRemoteDataSource remote,
    required String Function() currentUserId,
  })  : _remote = remote,
        _currentUserId = currentUserId;

  final IntegrationsRemoteDataSource _remote;
  final String Function() _currentUserId;

  Failure _classify(Object e) {
    if (e is PostgrestException) return ServerFailure(e.message);
    if (e is DioException) {
      return e.response?.statusCode != null
          ? ServerFailure('http ${e.response!.statusCode}')
          : const NetworkFailure('http error');
    }
    if (e is SocketException) return const NetworkFailure('offline');
    return UnknownFailure(e.toString());
  }

  @override
  Future<Either<Failure, GitHubIntegration>> currentGithub() async {
    try {
      final row = await _remote.readGithub(userId: _currentUserId());
      if (row == null) {
        return const Right(GitHubIntegration(login: null, connected: false));
      }
      return Right(GitHubIntegration(
        login: row['github_login'] as String?,
        connected: row['github_token'] != null,
      ));
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, GitHubIntegration>> connectGithub({required String token}) async {
    try {
      final login = await _remote.validateGithubToken(token);
      await _remote.upsertGithub(
        userId: _currentUserId(),
        token: token,
        login: login,
      );
      return Right(GitHubIntegration(login: login, connected: true));
    } on FormatException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, void>> disconnectGithub() async {
    try {
      await _remote.deleteGithub(userId: _currentUserId());
      return const Right(null);
    } catch (e) {
      return Left(_classify(e));
    }
  }
}
