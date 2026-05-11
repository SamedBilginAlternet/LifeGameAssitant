import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/cover_photo/presentation/widgets/cover_photo_chip.dart';
import 'package:memoir_log/features/cover_photo/presentation/widgets/cover_photo_view.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
import 'package:memoir_log/features/diary/presentation/widgets/pixel_meter.dart';
import 'package:memoir_log/features/diary/presentation/widgets/share_card.dart';
import 'package:memoir_log/features/diary/presentation/widgets/typewriter_text.dart';
import 'package:memoir_log/features/voice_notes/presentation/widgets/voice_note_card.dart';
import 'package:memoir_log/features/voice_notes/presentation/widgets/voice_note_chip.dart';

/// One day = one terminal-window page on the timeline.
class DiaryPage extends StatefulWidget {
  const DiaryPage({super.key, required this.entry});

  final Entry entry;

  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  final GlobalKey _boundaryKey = GlobalKey();

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _share() async {
    unawaited(HapticFeedback.mediumImpact());
    final dateLabel = DateFormat('dd-MMM-yyyy').format(widget.entry.localDate);
    await captureAndShareDiaryPage(
      boundaryKey: _boundaryKey,
      subject: 'memoir_log · $dateLabel',
    );
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final entry = widget.entry;
    final dateFmt = DateFormat(
      'EEE  dd-MMM-yyyy',
    ).format(entry.localDate).toUpperCase();
    final isToday = _isToday(entry.localDate);

    return GestureDetector(
      onLongPress: _share,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: crt.bgSurface,
            border: Border.all(color: crt.fgDim),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(date: dateFmt, skill: entry.topSkill),
              const SizedBox(height: 16),
              _Body(entry: entry),
              if (entry.stats != null && entry.status == EntryStatus.ok) ...[
                const SizedBox(height: 16),
                _StatStrip(stats: entry.stats!),
              ],
              const SizedBox(height: 8),
              CoverPhotoView(localDate: entry.localDate),
              VoiceNoteCard(localDate: entry.localDate),
              if (isToday) ...[
                CoverPhotoChip(localDate: entry.localDate),
                VoiceNoteChip(localDate: entry.localDate),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders pixel meters for the metrics that exist in the day's stats.
/// Targets are sensible defaults — Phase 4+ will read user-set goals
/// from the profile.
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final fitness = stats['fitness_data'] as Map<String, dynamic>?;
    final learning = stats['learning_logs'] as List<dynamic>?;
    final github = stats['github_events'] as Map<String, dynamic>?;

    final commits = (github?['commits'] as num?)?.toInt() ?? 0;
    final steps = (fitness?['steps'] as num?) ?? 0;
    final protein = (fitness?['protein_g'] as num?) ?? 0;
    final germanMinutes = (learning ?? [])
        .whereType<Map<String, dynamic>>()
        .where((e) => e['track'] == 'german')
        .fold<num>(0, (sum, e) => sum + ((e['minutes'] as num?) ?? 0));

    final rows = <Widget>[];
    if (commits > 0) {
      rows.add(
        PixelMeter(label: 'commits', value: commits, target: 10, unit: ''),
      );
    }
    if (steps > 0) {
      rows.add(
        PixelMeter(label: 'steps', value: steps, target: 10000, unit: ''),
      );
    }
    if (protein > 0) {
      rows.add(
        PixelMeter(label: 'protein', value: protein, target: 180, unit: 'g'),
      );
    }
    if (germanMinutes > 0) {
      rows.add(
        PixelMeter(
          label: 'german',
          value: germanMinutes,
          target: 30,
          unit: 'm',
        ),
      );
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: crt.fgGhost),
        const SizedBox(height: 8),
        ...rows,
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.date, required this.skill});
  final String date;
  final TopSkill? skill;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Row(
      children: [
        Text('[ $date ]', style: crt.dateHeaderType),
        const Spacer(),
        if (skill != null) ...[
          Container(width: 6, height: 6, color: crt.fgBright),
          const SizedBox(width: 6),
          Text(skill!.label, style: crt.uiType.copyWith(color: crt.fgBright)),
        ],
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.entry});
  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    switch (entry.status) {
      case EntryStatus.ok:
        return TypewriterText(
          // Keying by entry.id means scrolling back doesn't re-replay
          // clicks; only the first reveal types out.
          key: ValueKey('entry-${entry.id}'),
          text: '> ${entry.body ?? ''}',
          style: crt.bodyType,
        );
      case EntryStatus.empty:
        return Text(
          '> NO DATA RECORDED FOR THIS DAY.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        );
      case EntryStatus.failed:
        return Text(
          '> NARRATOR OFFLINE. RETRY AT 23:50 TOMORROW.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        );
    }
  }
}
