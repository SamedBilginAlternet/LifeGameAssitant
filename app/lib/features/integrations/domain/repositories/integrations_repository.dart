import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/integrations/domain/entities/integration_health.dart';

class GitHubIntegration {
  const GitHubIntegration({required this.login, required this.connected});
  final String? login;
  final bool connected;
}

class SpotifyIntegration {
  const SpotifyIntegration({
    required this.userId,
    required this.connected,
    this.lastPolledAt,
  });
  final String? userId;
  final bool connected;
  final DateTime? lastPolledAt;
}

abstract class IntegrationsRepository {
  // GitHub --------------------------------------------------------------
  Future<Either<Failure, GitHubIntegration>> currentGithub();
  Future<Either<Failure, GitHubIntegration>> connectGithub({
    required String token,
  });
  Future<Either<Failure, void>> disconnectGithub();

  // Spotify -------------------------------------------------------------
  Future<Either<Failure, SpotifyIntegration>> currentSpotify();

  /// Performs the PKCE auth-code exchange via the
  /// `spotify-token-exchange` Edge Function and persists the refresh
  /// token. Returns the resulting [SpotifyIntegration] on success.
  Future<Either<Failure, SpotifyIntegration>> connectSpotify();

  Future<Either<Failure, void>> disconnectSpotify();

  // Health ------------------------------------------------------------
  /// Returns one health row per known integration kind. A poll is
  /// classified [stale] if its last successful run is older than 90
  /// minutes (poll cadence is every 30 min so 3× the cadence is the
  /// "something's wrong" threshold).
  Future<Either<Failure, List<IntegrationHealth>>> healthSnapshot();
}
