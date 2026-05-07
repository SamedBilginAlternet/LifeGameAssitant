import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
import 'package:memoir_log/features/diary/domain/failures/diary_failure.dart';
import 'package:memoir_log/features/diary/presentation/providers/diary_providers.dart';
import 'package:memoir_log/features/diary/presentation/widgets/diary_page.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    final entries = ref.watch(entriesStreamProvider);

    return Scaffold(
      backgroundColor: crt.bgCanvas,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(),
            Expanded(
              child: entries.when(
                loading: () => Center(
                  child: Text(
                    '> CONNECTING...',
                    style: crt.bodyType.copyWith(color: crt.fgDim),
                  ),
                ),
                error: (e, _) => _ErrorBlock(message: e.toString()),
                data: (either) => either.fold(
                  (failure) => _ErrorBlock(message: failure.message),
                  (list) => _EntriesList(entries: list, onRefresh: () => _refresh(ref)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final result = await ref.read(resummarizeTodayProvider).call();
    result.match(
      (_) => null,
      (_) => null,
    );
  }
}

class _AppBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Text('MEMOIR_LOG  v1.0', style: crt.dateHeaderType),
          const Spacer(),
          IconButton(
            tooltip: 'Capture',
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/capture');
            },
            icon: Text('[+]', style: crt.uiType.copyWith(color: crt.fgBright)),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              HapticFeedback.selectionClick();
              await ref.read(supabaseClientProvider).auth.signOut();
            },
            icon: Text('[X]', style: crt.uiType.copyWith(color: crt.fgDim)),
          ),
        ],
      ),
    );
  }
}

class _EntriesList extends StatelessWidget {
  const _EntriesList({required this.entries, required this.onRefresh});

  final List<Entry> entries;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    if (entries.isEmpty) {
      return RefreshIndicator(
        color: crt.fgBright,
        backgroundColor: crt.bgSurface,
        onRefresh: onRefresh,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text('> NO ENTRIES YET. LIVE A DAY._', style: crt.bodyType),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: crt.fgBright,
      backgroundColor: crt.bgSurface,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: entries.length,
        itemBuilder: (context, i) => DiaryPage(entry: entries[i]),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          '> CONNECTION TIMEOUT.\n> ${message.toUpperCase()}',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        ),
      ),
    );
  }
}

DiaryFailure _typed(Object f) => f as DiaryFailure;
