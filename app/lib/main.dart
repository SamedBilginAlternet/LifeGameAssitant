import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/router.dart';
import 'package:memoir_log/app/theme/scanline_overlay.dart';
import 'package:memoir_log/app/theme/theme_provider.dart';
import 'package:memoir_log/app/theme/themes.dart';
import 'package:memoir_log/core/env.dart';
import 'package:memoir_log/core/mood_prompt_providers.dart';
import 'package:memoir_log/core/mood_prompt_service.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/fitness_sync/presentation/providers/fitness_sync_providers.dart';
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

class MemoirLogApp extends ConsumerStatefulWidget {
  const MemoirLogApp({super.key});

  @override
  ConsumerState<MemoirLogApp> createState() => _MemoirLogAppState();
}

class _MemoirLogAppState extends ConsumerState<MemoirLogApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold-start sync once a signed-in user is observed. Fires on every
    // launch; the upsert is idempotent on (user_id, local_date, metric).
    _maybeSyncFitness();
    // Touch the mood-prompt provider so it reads the persisted toggle
    // and (re)schedules the daily 22:30 notification on every cold
    // start. The schedule is idempotent inside the plugin.
    ref.read(moodPromptEnabledProvider);
    // Notification tap → capture screen.
    MoodPromptService.onTapHandler = (_) {
      ref.read(routerProvider).push('/capture');
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeSyncFitness();
    }
  }

  void _maybeSyncFitness() {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final repo = ref.read(fitnessSyncRepositoryProvider);
    unawaited(repo.syncToday());
  }

  @override
  Widget build(BuildContext context) {
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
