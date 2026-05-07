import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User's selected CRT palette. Persisted to Supabase `profiles.palette`
/// in Phase 2 — for now the choice lives in memory.
enum CrtPalette { amber, phosphor }

final crtPaletteProvider = StateProvider<CrtPalette>((ref) {
  return CrtPalette.amber;
});
