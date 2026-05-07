import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/diary/data/datasources/diary_remote_data_source.dart';
import 'package:memoir_log/features/diary/data/repositories/diary_repository_impl.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
import 'package:memoir_log/features/diary/domain/failures/diary_failure.dart';
import 'package:memoir_log/features/diary/domain/repositories/diary_repository.dart';
import 'package:memoir_log/features/diary/domain/usecases/resummarize_today.dart';
import 'package:memoir_log/features/diary/domain/usecases/watch_entries.dart';

final diaryRemoteDataSourceProvider = Provider<DiaryRemoteDataSource>((ref) {
  return DiaryRemoteDataSourceImpl(ref.read(supabaseClientProvider));
});

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) {
  return DiaryRepositoryImpl(
    remote: ref.read(diaryRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});

final watchEntriesProvider = Provider<WatchEntries>((ref) {
  return WatchEntries(ref.read(diaryRepositoryProvider));
});

final resummarizeTodayProvider = Provider<ResummarizeToday>((ref) {
  return ResummarizeToday(ref.read(diaryRepositoryProvider));
});

/// The timeline's data source. Streams the full sorted entry list.
final entriesStreamProvider = StreamProvider<Either<DiaryFailure, List<Entry>>>((ref) {
  // Re-establishes the stream on auth changes so a re-login
  // re-subscribes against the new user_id.
  ref.watch(currentUserProvider);
  return ref.read(watchEntriesProvider).call();
});
