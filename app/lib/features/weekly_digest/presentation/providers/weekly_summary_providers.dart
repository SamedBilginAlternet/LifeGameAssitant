import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/weekly_digest/data/datasources/weekly_summary_remote_data_source.dart';
import 'package:memoir_log/features/weekly_digest/data/repositories/weekly_summary_repository_impl.dart';
import 'package:memoir_log/features/weekly_digest/domain/entities/weekly_summary.dart';
import 'package:memoir_log/features/weekly_digest/domain/repositories/weekly_summary_repository.dart';

final weeklySummaryRemoteDataSourceProvider =
    Provider<WeeklySummaryRemoteDataSource>((ref) {
      return WeeklySummaryRemoteDataSource(ref.read(supabaseClientProvider));
    });

final weeklySummaryRepositoryProvider = Provider<WeeklySummaryRepository>((
  ref,
) {
  return WeeklySummaryRepositoryImpl(
    remote: ref.read(weeklySummaryRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});

/// Refreshed on auth state changes so a sign-in / sign-out re-fetches
/// against the right user.
final recentWeeklySummariesProvider =
    FutureProvider<Either<Failure, List<WeeklySummary>>>((ref) async {
      ref.watch(currentUserProvider);
      return ref.read(weeklySummaryRepositoryProvider).recent();
    });
