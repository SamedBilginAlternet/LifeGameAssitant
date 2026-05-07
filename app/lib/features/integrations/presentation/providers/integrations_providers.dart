import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/integrations/data/datasources/integrations_remote_data_source.dart';
import 'package:memoir_log/features/integrations/data/repositories/integrations_repository_impl.dart';
import 'package:memoir_log/features/integrations/domain/entities/integration_health.dart';
import 'package:memoir_log/features/integrations/domain/repositories/integrations_repository.dart';

final integrationsRemoteDataSourceProvider =
    Provider<IntegrationsRemoteDataSource>((ref) {
  return IntegrationsRemoteDataSource(ref.read(supabaseClientProvider));
});

final integrationsRepositoryProvider = Provider<IntegrationsRepository>((ref) {
  return IntegrationsRepositoryImpl(
    remote: ref.read(integrationsRemoteDataSourceProvider),
    currentUserId: () {
      final user = ref.read(currentUserProvider);
      if (user == null) throw StateError('No signed-in user');
      return user.id;
    },
  );
});

final githubIntegrationProvider =
    FutureProvider<Either<Failure, GitHubIntegration>>((ref) async {
  return ref.read(integrationsRepositoryProvider).currentGithub();
});

final spotifyIntegrationProvider =
    FutureProvider<Either<Failure, SpotifyIntegration>>((ref) async {
  return ref.read(integrationsRepositoryProvider).currentSpotify();
});

final integrationsHealthProvider =
    FutureProvider<Either<Failure, List<IntegrationHealth>>>((ref) async {
  return ref.read(integrationsRepositoryProvider).healthSnapshot();
});
