import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';

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
}
