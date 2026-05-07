import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/capture/presentation/providers/capture_providers.dart';
import 'package:memoir_log/features/capture/presentation/widgets/log_scaffold.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';

class LogRideScreen extends ConsumerStatefulWidget {
  const LogRideScreen({super.key});

  @override
  ConsumerState<LogRideScreen> createState() => _LogRideScreenState();
}

class _LogRideScreenState extends ConsumerState<LogRideScreen> {
  final _distance = TextEditingController();
  final _duration = TextEditingController();
  final _route = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _distance.dispose();
    _duration.dispose();
    _route.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return LogScaffold(
      title: 'RIDE — 250NK',
      onSave: () {
        final dist = num.tryParse(_distance.text.trim()) ?? 0;
        return ref.read(captureRepositoryProvider).logRide(
              distanceKm: dist,
              durationMin: int.tryParse(_duration.text.trim()),
              routeTag: _route.text.trim().isEmpty ? null : _route.text.trim(),
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            );
      },
      children: [
        TerminalField(
          controller: _distance,
          label: 'DISTANCE (km)',
          hint: '18',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        TerminalField(
          controller: _duration,
          label: 'DURATION (min)',
          hint: '30',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TerminalField(
          controller: _route,
          label: 'ROUTE TAG',
          hint: 'commute / bosphorus / anatolian side',
        ),
        const SizedBox(height: 16),
        TerminalField(
          controller: _notes,
          label: 'NOTES',
          hint: 'cool evening, no traffic...',
          maxLength: 280,
        ),
        const SizedBox(height: 16),
        Text(
          '> distance is required. everything else makes the diary\n  mention the ride more vividly.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        ),
      ],
    );
  }
}
