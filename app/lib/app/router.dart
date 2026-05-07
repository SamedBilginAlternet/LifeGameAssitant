import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/auth/presentation/screens/login_screen.dart';
import 'package:memoir_log/features/capture/presentation/screens/capture_screen.dart';
import 'package:memoir_log/features/diary/presentation/screens/timeline_screen.dart';

/// Top-level router. Auth state drives redirects — when the user signs
/// in or out, the redirect callback runs and the router lands on the
/// right screen automatically.
final routerProvider = Provider<GoRouter>((ref) {
  // Watching the auth stream means the router rebuilds on login/logout.
  ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/timeline',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final loggingIn = state.matchedLocation == '/login';

      if (user == null) return loggingIn ? null : '/login';
      if (loggingIn) return '/timeline';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/timeline',
        builder: (context, state) => const TimelineScreen(),
      ),
      GoRoute(
        path: '/capture',
        builder: (context, state) => const CaptureScreen(),
      ),
    ],
  );
});
