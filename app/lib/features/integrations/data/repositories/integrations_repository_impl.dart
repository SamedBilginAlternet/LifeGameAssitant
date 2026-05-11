import 'dart:io';

import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/env.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/integrations/data/datasources/integrations_remote_data_source.dart';
import 'package:memoir_log/features/integrations/data/datasources/spotify_oauth.dart';
import 'package:memoir_log/features/integrations/domain/entities/integration_health.dart';
import 'package:memoir_log/features/integrations/domain/repositories/integrations_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class IntegrationsRepositoryImpl implements IntegrationsRepository {
  IntegrationsRepositoryImpl({
    required IntegrationsRemoteDataSource remote,
    required String Function() currentUserId,
    SpotifyOAuth? spotifyOAuth,
  }) : _remote = remote,
       _currentUserId = currentUserId,
       _spotifyOAuth = spotifyOAuth ?? SpotifyOAuth();

  final IntegrationsRemoteDataSource _remote;
  final String Function() _currentUserId;
  final SpotifyOAuth _spotifyOAuth;

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

  // ── GitHub ─────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, GitHubIntegration>> currentGithub() async {
    try {
      final row = await _remote.readGithub(userId: _currentUserId());
      if (row == null) {
        return const Right(GitHubIntegration(login: null, connected: false));
      }
      return Right(
        GitHubIntegration(
          login: row['github_login'] as String?,
          connected: row['github_token'] != null,
        ),
      );
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, GitHubIntegration>> connectGithub({
    required String token,
  }) async {
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

  // ── Spotify ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, SpotifyIntegration>> currentSpotify() async {
    try {
      final row = await _remote.readSpotify(userId: _currentUserId());
      if (row == null) {
        return const Right(SpotifyIntegration(userId: null, connected: false));
      }
      final lastPolled = row['spotify_last_polled'];
      return Right(
        SpotifyIntegration(
          userId: row['spotify_user_id'] as String?,
          connected: row['spotify_refresh_token'] != null,
          lastPolledAt: lastPolled is String
              ? DateTime.tryParse(lastPolled)
              : null,
        ),
      );
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, SpotifyIntegration>> connectSpotify() async {
    if (!Env.spotifyConfigured) {
      return const Left(AuthFailure('SPOTIFY_CLIENT_ID not set'));
    }
    try {
      final auth = await _spotifyOAuth.authorize(
        clientId: Env.spotifyClientId,
        redirectUri: Env.spotifyRedirectUri,
      );
      final spotifyUserId = await _remote.exchangeSpotifyCode(
        code: auth.code,
        codeVerifier: auth.codeVerifier,
        redirectUri: Env.spotifyRedirectUri,
      );
      return Right(
        SpotifyIntegration(
          userId: spotifyUserId,
          connected: true,
          lastPolledAt: null,
        ),
      );
    } on FormatException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, void>> disconnectSpotify() async {
    try {
      await _remote.clearSpotify(userId: _currentUserId());
      return const Right(null);
    } catch (e) {
      return Left(_classify(e));
    }
  }

  // ── Health ─────────────────────────────────────────────────────────

  static const _staleAfter = Duration(minutes: 90);
  static const _knownKinds = ['github_poll', 'spotify_poll'];

  @override
  Future<Either<Failure, List<IntegrationHealth>>> healthSnapshot() async {
    try {
      final rows = await _remote.latestRuns(userId: _currentUserId());

      // Reduce to the most recent run per kind.
      final latestByKind = <String, Map<String, dynamic>>{};
      for (final row in rows) {
        final kind = row['kind'] as String?;
        if (kind == null) continue;
        latestByKind.putIfAbsent(kind, () => row);
      }

      final now = DateTime.now();
      final out = <IntegrationHealth>[];
      for (final kind in _knownKinds) {
        final row = latestByKind[kind];
        if (row == null) {
          out.add(
            IntegrationHealth(
              kind: kind,
              status: IntegrationHealthStatus.never,
            ),
          );
          continue;
        }
        final ranAt = DateTime.tryParse(row['ran_at'] as String? ?? '');
        final status = row['status'] as String?;
        final error = row['error'] as String?;
        final IntegrationHealthStatus mapped;
        if (status == 'error') {
          mapped = IntegrationHealthStatus.failed;
        } else if (ranAt != null && now.difference(ranAt) > _staleAfter) {
          mapped = IntegrationHealthStatus.stale;
        } else {
          mapped = IntegrationHealthStatus.ok;
        }
        out.add(
          IntegrationHealth(
            kind: kind,
            status: mapped,
            lastRunAt: ranAt,
            error: error,
          ),
        );
      }
      return Right(out);
    } catch (e) {
      return Left(_classify(e));
    }
  }
}
