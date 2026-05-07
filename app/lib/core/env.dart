/// Compile-time environment, sourced from `--dart-define` flags.
///
/// Required at run time:
///   --dart-define=SUPABASE_URL=https://<project>.supabase.co
///   --dart-define=SUPABASE_ANON_KEY=<anon_public_key>
///
/// Optional (Phase 4.5+ Spotify connect flow):
///   --dart-define=SPOTIFY_CLIENT_ID=<client_id from developer.spotify.com>
///   --dart-define=SPOTIFY_REDIRECT_URI=memoirlog://spotify-callback
///
/// See app/SETUP.md for the full run command and VS Code launch config.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static const spotifyClientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');
  static const spotifyRedirectUri = String.fromEnvironment(
    'SPOTIFY_REDIRECT_URI',
    defaultValue: 'memoirlog://spotify-callback',
  );

  static bool get spotifyConfigured => spotifyClientId.isNotEmpty;

  /// Throws a clear error early if the build was started without the
  /// required env. Better to crash on boot than silently 401 later.
  static void assertConfigured() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'MEMOIR_LOG was launched without SUPABASE_URL or SUPABASE_ANON_KEY. '
        'See app/SETUP.md for the run command.',
      );
    }
  }
}
