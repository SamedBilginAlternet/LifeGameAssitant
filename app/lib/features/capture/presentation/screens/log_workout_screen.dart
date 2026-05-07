import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/features/capture/presentation/providers/capture_providers.dart';
import 'package:memoir_log/features/capture/presentation/widgets/log_scaffold.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';

class LogWorkoutScreen extends ConsumerStatefulWidget {
  const LogWorkoutScreen({super.key});

  @override
  ConsumerState<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends ConsumerState<LogWorkoutScreen> {
  final _name = TextEditingController(text: 'Push Day');
  final _duration = TextEditingController();
  final _volume = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _volume.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LogScaffold(
      title: 'WORKOUT',
      onSave: () => ref.read(captureRepositoryProvider).logWorkout(
            name: _name.text.trim().isEmpty ? 'Workout' : _name.text.trim(),
            durationMin: int.tryParse(_duration.text.trim()),
            totalVolumeKg: num.tryParse(_volume.text.trim()),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          ),
      children: [
        TerminalField(controller: _name, label: 'NAME', hint: 'Push Day...'),
        const SizedBox(height: 16),
        TerminalField(
          controller: _duration,
          label: 'DURATION (min)',
          hint: '60',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TerminalField(
          controller: _volume,
          label: 'TOTAL VOLUME (kg)',
          hint: '4200',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        TerminalField(
          controller: _notes,
          label: 'NOTES',
          hint: 'felt strong on bench...',
          maxLength: 280,
        ),
      ],
    );
  }
}
