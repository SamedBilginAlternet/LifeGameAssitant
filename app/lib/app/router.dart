import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/auth/presentation/screens/login_screen.dart';
import 'package:memoir_log/features/capture/presentation/screens/capture_screen.dart';
import 'package:memoir_log/features/capture/presentation/screens/log_meal_screen.dart';
import 'package:memoir_log/features/capture/presentation/screens/log_movie_screen.dart';
import 'package:memoir_log/features/capture/presentation/screens/log_picker_screen.dart';
import 'package:memoir_log/features/capture/presentation/screens/log_ride_screen.dart';
import 'package:memoir_log/features/capture/presentation/screens/log_workout_screen.dart';
import 'package:memoir_log/features/diary/presentation/screens/timeline_screen.dart';
import 'package:memoir_log/features/integrations/presentation/screens/connect_github_screen.dart';
import 'package:memoir_log/features/settings/presentation/screens/settings_screen.dart';

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
      GoRoute(
        path: '/log',
        builder: (context, state) => const LogPickerScreen(),
      ),
      GoRoute(
        path: '/log/meal',
        builder: (context, state) => const LogMealScreen(),
      ),
      GoRoute(
        path: '/log/workout',
        builder: (context, state) => const LogWorkoutScreen(),
      ),
      GoRoute(
        path: '/log/movie',
        builder: (context, state) => const LogMovieScreen(),
      ),
      GoRoute(
        path: '/log/ride',
        builder: (context, state) => const LogRideScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/integrations/github',
        builder: (context, state) => const ConnectGithubScreen(),
      ),
    ],
  );
});
