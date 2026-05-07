import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';

class GitHubIntegration {
  const GitHubIntegration({required this.login, required this.connected});
  final String? login;
  final bool connected;
}

abstract class IntegrationsRepository {
  /// Reads the current row, if any.
  Future<Either<Failure, GitHubIntegration>> currentGithub();

  /// Validates the token against GET /user, then upserts the row.
  Future<Either<Failure, GitHubIntegration>> connectGithub({
    required String token,
  });

  /// Removes the row entirely.
  Future<Either<Failure, void>> disconnectGithub();
}
