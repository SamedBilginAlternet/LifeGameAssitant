import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single SupabaseClient for the app. Bootstrapped in main.dart via
/// Supabase.initialize() — this provider just exposes the singleton so
/// data sources can depend on it without importing Supabase globals.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams the current auth state. Login/logout flips this without any
/// manual refresh — the router watches it to gate access.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The currently signed-in user, or null. Synchronous — backed by the
/// Supabase client's locally cached session.
final currentUserProvider = Provider<User?>((ref) {
  // Re-evaluates whenever auth state changes.
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentUser;
});
