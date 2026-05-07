import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/diary/domain/entities/entry.dart';
import 'package:memoir_log/features/diary/presentation/widgets/typewriter_text.dart';

/// One day = one terminal-window page on the timeline.
class DiaryPage extends StatelessWidget {
  const DiaryPage({super.key, required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final dateFmt = DateFormat('EEE  dd-MMM-yyyy').format(entry.localDate).toUpperCase();

    return Container(
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
        ],
      ),
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
          Text(
            skill!.label,
            style: crt.uiType.copyWith(color: crt.fgBright),
          ),
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
