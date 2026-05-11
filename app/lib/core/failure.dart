/// Base sealed class for all repository-boundary failures. Per
/// docs/CODE_STANDARDS.md, exceptions are caught at the data layer and
/// converted to Either<Failure, T> — they never cross into domain or
/// presentation. Pattern-matching on the sealed hierarchy gives us
/// exhaustive UI handling.
abstract base class Failure {
  const Failure(this.message);
  final String message;

  @override
  String toString() => '$runtimeType($message)';
}

final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

final class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

final class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

final class NarratorFailure extends Failure {
  const NarratorFailure(super.message);
}

final class UnknownFailure extends Failure {
  const UnknownFailure(super.message);
}
