import 'package:memoir_log/core/failure.dart';

/// Diary-specific failures. Extends the shared sealed [Failure] base
/// so the presentation layer can pattern-match exhaustively.
sealed class DiaryFailure extends Failure {
  const DiaryFailure(super.message);
}

final class DiaryNetworkFailure extends DiaryFailure {
  const DiaryNetworkFailure(super.message);
}

final class DiaryServerFailure extends DiaryFailure {
  const DiaryServerFailure(super.message);
}

final class DiaryNotFound extends DiaryFailure {
  const DiaryNotFound() : super('no entry');
}

final class DiaryUnknownFailure extends DiaryFailure {
  const DiaryUnknownFailure(super.message);
}
