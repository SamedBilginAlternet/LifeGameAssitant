import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/capture/presentation/providers/capture_providers.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';

/// Phase 1 capture screen — manual quick-add for the four MVP fields.
/// Phase 4 expands this with movie / meal / motorcycle / workout sheets.
class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  final _proteinCtl = TextEditingController();
  final _germanMinCtl = TextEditingController();
  final _germanTopicCtl = TextEditingController();
  final _noteCtl = TextEditingController();
  int _mood = 7;
  bool _busy = false;
  String? _statusLine;

  @override
  void dispose() {
    _proteinCtl.dispose();
    _germanMinCtl.dispose();
    _germanTopicCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusLine = '> SAVING...';
    });
    HapticFeedback.mediumImpact();

    final repo = ref.read(captureRepositoryProvider);
    final results = <Either<Failure, void>>[];

    results.add(await repo.saveMood(score: _mood));

    final proteinValue = num.tryParse(_proteinCtl.text.trim());
    if (proteinValue != null && proteinValue > 0) {
      results.add(
        await repo.saveFitnessMetric(metric: 'protein_g', value: proteinValue),
      );
    }

    final germanMinutes = int.tryParse(_germanMinCtl.text.trim());
    if (germanMinutes != null && germanMinutes > 0) {
      results.add(
        await repo.logLearning(
          track: 'german',
          minutes: germanMinutes,
          topic: _germanTopicCtl.text.trim().isEmpty
              ? null
              : _germanTopicCtl.text.trim(),
        ),
      );
    }

    final note = _noteCtl.text.trim();
    if (note.isNotEmpty) {
      results.add(await repo.saveNote(note: note));
    }

    final firstFailure = results.firstWhere(
      (r) => r.isLeft(),
      orElse: () => const Right<Failure, void>(null),
    );

    if (!mounted) return;

    firstFailure.match(
      (failure) {
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _statusLine = '> SAVE FAILED: ${failure.message.toUpperCase()}';
        });
      },
      (_) {
        HapticFeedback.mediumImpact();
        setState(() {
          _busy = false;
          _statusLine = '> SAVED. RETURNING...';
        });
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          if (mounted) context.pop();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Scaffold(
      backgroundColor: crt.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            context.pop();
                          },
                    icon: Text(
                      '[<]',
                      style: crt.uiType.copyWith(color: crt.fgBright),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('CAPTURE', style: crt.dateHeaderType),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _MoodSlider(
                      value: _mood,
                      onChanged: (v) => setState(() => _mood = v),
                    ),
                    const SizedBox(height: 24),
                    TerminalField(
                      controller: _proteinCtl,
                      label: 'PROTEIN (g)',
                      hint: '0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    TerminalField(
                      controller: _germanMinCtl,
                      label: 'GERMAN MINUTES',
                      hint: '0',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TerminalField(
                      controller: _germanTopicCtl,
                      label: 'GERMAN TOPIC (optional)',
                      hint: 'modalverben...',
                    ),
                    const SizedBox(height: 24),
                    TerminalField(
                      controller: _noteCtl,
                      label: 'NOTE',
                      hint: 'one line about today...',
                      maxLength: 280,
                    ),
                  ],
                ),
              ),
              if (_statusLine != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _statusLine!,
                    style: crt.bodyType.copyWith(color: crt.fgDim),
                  ),
                ),
              TerminalButton(
                label: _busy ? '[ SAVING... ]' : '[ SAVE ]',
                onTap: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodSlider extends StatelessWidget {
  const _MoodSlider({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '> MOOD  ${value.toString().padLeft(2, '0')} / 10',
          style: crt.uiType.copyWith(color: crt.fgDim),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: crt.fgBright,
            inactiveTrackColor: crt.fgGhost,
            thumbColor: crt.fgBright,
            overlayColor: crt.glow,
            trackHeight: 2,
          ),
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: value.toDouble(),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v.round());
            },
          ),
        ),
      ],
    );
  }
}
