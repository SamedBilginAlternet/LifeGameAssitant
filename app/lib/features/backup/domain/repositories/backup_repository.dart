import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';

abstract class BackupRepository {
  /// Reads every public table the user owns, composes a single JSON
  /// document, writes it to a temp file, and returns the path. Caller
  /// hands the path to share_plus.
  Future<Either<Failure, String>> exportToFile();
}
