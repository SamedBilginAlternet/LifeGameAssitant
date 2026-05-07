import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/voice_notes/data/datasources/voice_notes_remote_data_source.dart';
import 'package:memoir_log/features/voice_notes/data/datasources/voice_recorder.dart';
import 'package:memoir_log/features/voice_notes/domain/entities/voice_note.dart';
import 'package:memoir_log/features/voice_notes/domain/repositories/voice_notes_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VoiceNotesRepositoryImpl implements VoiceNotesRepository {
  VoiceNotesRepositoryImpl({
    required VoiceNotesRemoteDataSource remote,
    required VoiceRecorder recorder,
    required String Function() currentUserId,
  })  : _remote = remote,
        _recorder = recorder,
        _currentUserId = currentUserId;

  final VoiceNotesRemoteDataSource _remote;
  final VoiceRecorder _recorder;
  final String Function() _currentUserId;

  DateTime? _startedAt;

  Failure _classify(Object e) {
    if (e is StorageException) return ServerFailure(e.message);
    if (e is PostgrestException) return ServerFailure(e.message);
    if (e is SocketException) return const NetworkFailure('offline');
    return UnknownFailure(e.toString());
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<Either<Failure, VoiceNote?>> noteFor(DateTime localDate) async {
    try {
      final row = await _remote.readNote(
        userId: _currentUserId(),
        localDate: _isoDate(localDate),
      );
      return Right(row == null ? null : _fromRow(row, localDate));
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, void>> startRecording() async {
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        return const Left(AuthFailure('microphone permission denied'));
      }
      await _recorder.start();
      _startedAt = DateTime.now();
      return const Right(null);
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, VoiceNote>> stopAndUpload(DateTime localDate) async {
    try {
      final file = await _recorder.stop();
      final startedAt = _startedAt ?? DateTime.now();
      _startedAt = null;
      if (file == null) {
        return const Left(UnknownFailure('no recording captured'));
      }
      final bytes = await file.readAsBytes();
      final durationSec = DateTime.now().difference(startedAt).inSeconds;

      final iso = _isoDate(localDate);
      final userId = _currentUserId();
      final storagePath = '$userId/$iso.m4a';

      await _remote.uploadAudio(storagePath: storagePath, bytes: bytes);
      final row = await _remote.upsertNote(
        userId: userId,
        localDate: iso,
        storagePath: storagePath,
        durationSec: durationSec,
      );

      // Fire-and-forget the transcription. The diary card watches the
      // row, so when status flips to 'ok' the UI updates on its own.
      // Any error is captured server-side as status='failed'.
      try {
        await _remote.triggerTranscribe(row['id'] as String);
      } catch (_) {}

      return Right(_fromRow(row, localDate));
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, void>> cancelRecording() async {
    try {
      await _recorder.cancel();
      _startedAt = null;
      return const Right(null);
    } catch (e) {
      return Left(_classify(e));
    }
  }

  @override
  Future<Either<Failure, String>> signedAudioUrl(String storagePath) async {
    try {
      return Right(await _remote.signedAudioUrl(storagePath));
    } catch (e) {
      return Left(_classify(e));
    }
  }

  VoiceNote _fromRow(Map<String, dynamic> row, DateTime localDate) {
    return VoiceNote(
      id: row['id'] as String,
      localDate: localDate,
      storagePath: row['storage_path'] as String,
      durationSec: (row['duration_sec'] as num?)?.toInt() ?? 0,
      status: _statusFrom(row['status'] as String?),
      language: row['language'] as String?,
      transcriptDe: row['transcript_de'] as String?,
      transcriptEn: row['transcript_en'] as String?,
      corrections: _correctionsFrom(row['corrections']),
      error: row['error'] as String?,
    );
  }

  VoiceNoteStatus _statusFrom(String? raw) {
    switch (raw) {
      case 'ok':
        return VoiceNoteStatus.ok;
      case 'failed':
        return VoiceNoteStatus.failed;
      default:
        return VoiceNoteStatus.pending;
    }
  }

  List<CorrectionItem> _correctionsFrom(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map((m) {
      return CorrectionItem(
        original: (m['original'] as String?) ?? '',
        corrected: (m['corrected'] as String?) ?? '',
        note: (m['note'] as String?) ?? '',
      );
    }).toList();
  }
}
