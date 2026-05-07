import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/voice_notes/domain/entities/voice_note.dart';

abstract class VoiceNotesRepository {
  /// Returns the row for the day, or null if no recording exists.
  Future<Either<Failure, VoiceNote?>> noteFor(DateTime localDate);

  /// Begins a recording session. Caller stops via [stopAndUpload].
  /// Throws if microphone permission is denied.
  Future<Either<Failure, void>> startRecording();

  /// Stops the active recording, uploads to the voice/ bucket, inserts
  /// (or upserts) the voice_notes row in 'pending' status, and triggers
  /// the voice-transcribe Edge Function.
  ///
  /// Returns the freshly-uploaded note (still pending — the diary page
  /// reactively re-fetches once status flips to 'ok').
  Future<Either<Failure, VoiceNote>> stopAndUpload(DateTime localDate);

  /// Cancels an in-flight recording without uploading.
  Future<Either<Failure, void>> cancelRecording();

  /// Returns a short-lived signed URL for playback.
  Future<Either<Failure, String>> signedAudioUrl(String storagePath);
}
