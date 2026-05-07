import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';

/// The home tab. In Phase 0 it renders only the empty state — the
/// "no entries yet" line that the roadmap defines as the Phase 0
/// done-when. Real entries arrive in Phase 1 once the daily-summary
/// Edge Function and the entries table exist.
class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    return Scaffold(
      backgroundColor: crt.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MEMOIR_LOG  v1.0', style: crt.dateHeaderType),
              const SizedBox(height: 32),
              Expanded(
                child: Center(
                  child: Text(
                    '> NO ENTRIES YET. LIVE A DAY._',
                    style: crt.bodyType,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
