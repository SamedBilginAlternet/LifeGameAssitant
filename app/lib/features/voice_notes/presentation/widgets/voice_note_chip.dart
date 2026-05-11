import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/voice_notes/presentation/providers/voice_notes_providers.dart';

/// Press-and-hold mic capture, capped at 60 seconds.
///
/// While held → recording. Release → upload + trigger transcription.
/// Drag off the chip → cancel without upload.
class VoiceNoteChip extends ConsumerStatefulWidget {
  const VoiceNoteChip({super.key, required this.localDate});
  final DateTime localDate;

  @override
  ConsumerState<VoiceNoteChip> createState() => _VoiceNoteChipState();
}

class _VoiceNoteChipState extends ConsumerState<VoiceNoteChip> {
  bool _recording = false;
  bool _busy = false;
  Timer? _capTimer;

  Future<void> _start() async {
    if (_busy || _recording) return;
    unawaited(HapticFeedback.mediumImpact());
    final repo = ref.read(voiceNotesRepositoryProvider);
    final result = await repo.startRecording();
    result.match(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('mic: ${failure.message}')));
        }
      },
      (_) {
        setState(() => _recording = true);
        _capTimer = Timer(const Duration(seconds: 60), _stopAndUpload);
      },
    );
  }

  Future<void> _stopAndUpload() async {
    if (!_recording) return;
    _capTimer?.cancel();
    _capTimer = null;
    setState(() {
      _recording = false;
      _busy = true;
    });
    final repo = ref.read(voiceNotesRepositoryProvider);
    final result = await repo.stopAndUpload(widget.localDate);
    if (!mounted) return;
    result.match(
      (failure) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('upload: ${failure.message}')));
      },
      (_) {
        HapticFeedback.mediumImpact();
        ref.invalidate(voiceNoteForDateProvider(widget.localDate));
      },
    );
    setState(() => _busy = false);
  }

  Future<void> _cancel() async {
    if (!_recording) return;
    _capTimer?.cancel();
    _capTimer = null;
    final repo = ref.read(voiceNotesRepositoryProvider);
    await repo.cancelRecording();
    if (mounted) setState(() => _recording = false);
  }

  @override
  void dispose() {
    _capTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final label = _busy
        ? '[ UPLOADING... ]'
        : _recording
        ? '[ ● RELEASE TO SAVE ]'
        : '[ HOLD TO SPEAK ]';
    final color = _busy
        ? crt.fgDim
        : _recording
        ? crt.fgBright
        : crt.fgBright;

    return GestureDetector(
      onLongPressStart: (_) => _start(),
      onLongPressEnd: (_) => _stopAndUpload(),
      onLongPressMoveUpdate: (details) {
        // If the user drags more than ~64px from the chip, cancel.
        if (details.localOffsetFromOrigin.distance > 64) {
          _cancel();
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(label, style: crt.uiType.copyWith(color: color)),
      ),
    );
  }
}
