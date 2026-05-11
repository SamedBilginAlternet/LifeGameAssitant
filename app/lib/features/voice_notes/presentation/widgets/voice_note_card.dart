import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/voice_notes/domain/entities/voice_note.dart';
import 'package:memoir_log/features/voice_notes/presentation/providers/voice_notes_providers.dart';

/// Inline card on the diary page that shows the voice recording — play
/// button, raw transcript, English translation, and A2 corrections.
class VoiceNoteCard extends ConsumerWidget {
  const VoiceNoteCard({super.key, required this.localDate});
  final DateTime localDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final note = ref.watch(voiceNoteForDateProvider(localDate));
    return note.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (either) => either.fold(
        (_) => const SizedBox.shrink(),
        (n) => n == null ? const SizedBox.shrink() : _Card(note: n),
      ),
    );
  }
}

class _Card extends ConsumerStatefulWidget {
  const _Card({required this.note});
  final VoiceNote note;

  @override
  ConsumerState<_Card> createState() => _CardState();
}

class _CardState extends ConsumerState<_Card> {
  late final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    HapticFeedback.selectionClick();
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    final repo = ref.read(voiceNotesRepositoryProvider);
    final urlEither = await repo.signedAudioUrl(widget.note.storagePath);
    final url = urlEither.toOption().toNullable();
    if (url == null) return;
    await _player.play(UrlSource(url));
    setState(() => _playing = true);
    _player.onPlayerComplete.first.then((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final note = widget.note;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: crt.fgGhost)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InkWell(
                onTap: _togglePlay,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Text(
                    _playing ? '[ ❚❚ PAUSE ]' : '[ ▶ PLAY  ]',
                    style: crt.uiType.copyWith(color: crt.fgBright),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${note.durationSec}s',
                style: crt.uiType.copyWith(color: crt.fgDim),
              ),
              const Spacer(),
              _StatusBadge(status: note.status),
            ],
          ),
          if (note.status == VoiceNoteStatus.ok) ...[
            const SizedBox(height: 8),
            if (note.transcriptDe != null)
              Text(note.transcriptDe!, style: crt.bodyType),
            if (note.transcriptEn != null) ...[
              const SizedBox(height: 8),
              Text(
                note.transcriptEn!,
                style: crt.bodyType.copyWith(color: crt.fgDim),
              ),
            ],
            if (note.corrections.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('CORRECTIONS', style: crt.uiType.copyWith(color: crt.fgDim)),
              const SizedBox(height: 4),
              for (final c in note.corrections) _CorrectionRow(item: c),
            ],
          ],
          if (note.status == VoiceNoteStatus.failed && note.error != null) ...[
            const SizedBox(height: 8),
            Text(
              '> TRANSCRIPTION FAILED: ${note.error!.toUpperCase()}',
              style: crt.bodyType.copyWith(color: crt.fgDim),
            ),
          ],
        ],
      ),
    );
  }
}

class _CorrectionRow extends StatelessWidget {
  const _CorrectionRow({required this.item});
  final CorrectionItem item;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: crt.bodyType,
              children: [
                TextSpan(
                  text: item.original,
                  style: crt.bodyType.copyWith(
                    color: crt.fgDim,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                TextSpan(
                  text: '  →  ',
                  style: crt.bodyType.copyWith(color: crt.fgDim),
                ),
                TextSpan(
                  text: item.corrected,
                  style: crt.bodyType.copyWith(color: crt.fgBright),
                ),
              ],
            ),
          ),
          if (item.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '· ${item.note}',
                style: crt.uiType.copyWith(color: crt.fgDim),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final VoiceNoteStatus status;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final (label, color) = switch (status) {
      VoiceNoteStatus.pending => ('[TRANSCRIBING...]', crt.fgDim),
      VoiceNoteStatus.ok => ('[OK]', crt.fgBright),
      VoiceNoteStatus.failed => ('[FAILED]', crt.fgDim),
    };
    return Text(label, style: crt.uiType.copyWith(color: color));
  }
}
