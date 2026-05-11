import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/router.dart';
import 'package:memoir_log/app/theme/scanline_overlay.dart';
import 'package:memoir_log/app/theme/theme_provider.dart';
import 'package:memoir_log/app/theme/themes.dart';
import 'package:memoir_log/core/env.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();

  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);

  // The CRT is monochrome dark — lock the system chrome to match so the
  // status bar doesn't flash white on transitions.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: MemoirLogApp()));
}

class MemoirLogApp extends ConsumerWidget {
  const MemoirLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(crtPaletteProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'MEMOIR_LOG',
      debugShowCheckedModeBanner: false,
      theme: switch (palette) {
        CrtPalette.amber => buildAmberTheme(),
        CrtPalette.phosphor => buildPhosphorTheme(),
      },
      routerConfig: router,
      builder: (context, child) =>
          ScanlineOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}
