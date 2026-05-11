import 'dart:convert';
import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/backup/data/datasources/backup_remote_data_source.dart';
import 'package:memoir_log/features/backup/domain/repositories/backup_repository.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BackupRepositoryImpl implements BackupRepository {
  BackupRepositoryImpl({
    required BackupRemoteDataSource remote,
    required String Function() currentUserId,
  }) : _remote = remote,
       _currentUserId = currentUserId;

  final BackupRemoteDataSource _remote;
  final String Function() _currentUserId;

  Failure _classify(Object e) {
    if (e is PostgrestException) return ServerFailure(e.message);
    if (e is SocketException) return const NetworkFailure('offline');
    return UnknownFailure(e.toString());
  }

  @override
  Future<Either<Failure, String>> exportToFile() async {
    try {
      final userId = _currentUserId();
      final tables = await _remote.dumpAll(userId: userId);

      final payload = <String, dynamic>{
        'schema_version': 1,
        'exported_at': DateTime.now().toUtc().toIso8601String(),
        'user_id': userId,
        'tables': tables,
      };

      final jsonText = const JsonEncoder.withIndent('  ').convert(payload);

      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().replaceAll(
        RegExp(r'[:.]'),
        '-',
      );
      final file = File('${dir.path}/memoir_log_export_$stamp.json');
      await file.writeAsString(jsonText);

      return Right(file.path);
    } catch (e) {
      return Left(_classify(e));
    }
  }
}
