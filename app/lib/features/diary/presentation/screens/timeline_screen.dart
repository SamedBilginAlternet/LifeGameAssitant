import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
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
                  (list) => _EntriesList(
                    entries: list,
                    onRefresh: () => _refresh(ref),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    unawaited(HapticFeedback.lightImpact());
    final result = await ref.read(resummarizeTodayProvider).call();
    result.match((_) => null, (_) => null);
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
          const SizedBox(width: 12),
          const _TransmissionIndicator(),
          const Spacer(),
          IconButton(
            tooltip: 'Add to today',
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/log');
            },
            icon: Text('[+]', style: crt.uiType.copyWith(color: crt.fgBright)),
          ),
          IconButton(
            tooltip: 'Status',
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/skills');
            },
            icon: Text('[*]', style: crt.uiType.copyWith(color: crt.fgDim)),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              HapticFeedback.selectionClick();
              context.push('/settings');
            },
            icon: Text('[=]', style: crt.uiType.copyWith(color: crt.fgDim)),
          ),
        ],
      ),
    );
  }
}

/// Small blinking dot in the app bar — the "machine is alive" cue. Half-second
/// 50% duty cycle on the bright phosphor color; pauses under reduced motion.
class _TransmissionIndicator extends StatefulWidget {
  const _TransmissionIndicator();

  @override
  State<_TransmissionIndicator> createState() => _TransmissionIndicatorState();
}

class _TransmissionIndicatorState extends State<_TransmissionIndicator> {
  bool _on = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (mounted) setState(() => _on = !_on);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final reduced = MediaQuery.of(context).disableAnimations;
    final lit = reduced ? true : _on;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: lit ? crt.fgBright : crt.fgGhost,
            boxShadow: lit
                ? [BoxShadow(color: crt.glow, blurRadius: 6, spreadRadius: 1)]
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text('TX', style: crt.uiType.copyWith(color: crt.fgDim, fontSize: 10)),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: const [_EmptyHero()],
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

/// Empty-state hero: ASCII banner + tagline + quick-actions + a hint
/// pointing at integrations. Replaces the bare one-liner so first-launch
/// doesn't feel like a 404.
class _EmptyHero extends StatelessWidget {
  const _EmptyHero();

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final dim = crt.bodyType.copyWith(color: crt.fgDim);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ASCII banner — Press Start 2P would be too heavy here, so
          // use the body font and let VT323 carry the chrome.
          Text('┌──────────────────────────────────────────────┐', style: dim),
          Text(
            '│  MEMOIR_LOG  ·  DAY 0  ·  AWAITING TRANSMISSION  │',
            style: crt.bodyType,
          ),
          Text('└──────────────────────────────────────────────┘', style: dim),
          const SizedBox(height: 32),
          Text('> the diary that writes itself.', style: crt.bodyType),
          const SizedBox(height: 8),
          Text(
            '> log a fragment of your day below — at 23:50 a narrator',
            style: dim,
          ),
          Text('  stitches the lot into a page in your life.', style: dim),

          const SizedBox(height: 32),
          const _SectionLabel(label: 'QUICK CAPTURE'),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _QuickAction(label: '[ + MOOD     ]', route: '/capture'),
              _QuickAction(label: '[ + PROTEIN  ]', route: '/capture'),
              _QuickAction(label: '[ + GERMAN   ]', route: '/capture'),
              _QuickAction(label: '[ + MEAL     ]', route: '/log/meal'),
              _QuickAction(label: '[ + WORKOUT  ]', route: '/log/workout'),
              _QuickAction(label: '[ + MOVIE    ]', route: '/log/movie'),
              _QuickAction(label: '[ + RIDE     ]', route: '/log/ride'),
            ],
          ),

          const SizedBox(height: 32),
          const _SectionLabel(label: 'AUTO-CAPTURE'),
          const SizedBox(height: 12),
          Text(
            '> connect github and spotify in settings so commits + tracks',
            style: dim,
          ),
          Text('  feed the diary without a tap.', style: dim),
          const SizedBox(height: 12),
          const Row(
            children: [
              _QuickAction(label: '[ → SETTINGS  ]', route: '/settings'),
            ],
          ),

          const SizedBox(height: 48),
          Center(
            child: Text('> live a day. the page writes itself._', style: dim),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Row(
      children: [
        Text(label, style: crt.dateHeaderType.copyWith(color: crt.fgDim)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: crt.fgGhost)),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.route});
  final String label;
  final String route;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        GoRouter.of(context).push(route);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: crt.fgDim)),
        child: Text(label, style: crt.uiType.copyWith(color: crt.fgBright)),
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
