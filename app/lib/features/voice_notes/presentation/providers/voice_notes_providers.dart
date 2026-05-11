import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/voice_notes/data/datasources/voice_notes_remote_data_source.dart';
import 'package:memoir_log/features/voice_notes/data/datasources/voice_recorder.dart';
import 'package:memoir_log/features/voice_notes/data/repositories/voice_notes_repository_impl.dart';
import 'package:memoir_log/features/voice_notes/domain/entities/voice_note.dart';
import 'package:memoir_log/features/voice_notes/domain/repositories/voice_notes_repository.dart';

final voiceNotesRemoteDataSourceProvider = Provider<VoiceNotesRemoteDataSource>(
  (ref) {
    return VoiceNotesRemoteDataSource(ref.read(supabaseClientProvider));
  },
);

final voiceRecorderProvider = Provider<VoiceRecorder>((ref) {
  final recorder = VoiceRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});

final voiceNotesRepositoryProvider = Provider<VoiceNotesRepository>((ref) {
  return VoiceNotesRepositoryImpl(
    remote: ref.read(voiceNotesRemoteDataSourceProvider),
    recorder: ref.read(voiceRecorderProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});

final voiceNoteForDateProvider =
    FutureProvider.family<Either<Failure, VoiceNote?>, DateTime>((
      ref,
      date,
    ) async {
      return ref.read(voiceNotesRepositoryProvider).noteFor(date);
    });
