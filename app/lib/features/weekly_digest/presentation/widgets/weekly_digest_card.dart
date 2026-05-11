import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/diary/presentation/widgets/typewriter_text.dart';
import 'package:memoir_log/features/weekly_digest/domain/entities/weekly_summary.dart';

/// Sunday's synthesis, rendered above daily entries on the timeline.
/// Same chrome as DiaryPage but with a week-range header and a 'WEEKLY'
/// badge so it doesn't blur with the daily entries it summarises.
class WeeklyDigestCard extends StatelessWidget {
  const WeeklyDigestCard({super.key, required this.summary});
  final WeeklySummary summary;

  String _formatRange() {
    final fmt = DateFormat('dd-MMM');
    return '${fmt.format(summary.weekStartDate)} → ${fmt.format(summary.weekEndDate)}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final range = _formatRange();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: crt.bgSurface,
        border: Border.all(color: crt.fgBright),
        boxShadow: [
          BoxShadow(color: crt.glow, blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('[ WEEK · $range ]', style: crt.dateHeaderType),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: crt.fgBright),
                ),
                child: Text(
                  'WEEKLY',
                  style: crt.uiType.copyWith(color: crt.fgBright, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Body(summary: summary),
          if (summary.topSkill != null &&
              summary.status == WeeklySummaryStatus.ok) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: crt.fgGhost),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(width: 6, height: 6, color: crt.fgBright),
                const SizedBox(width: 6),
                Text(
                  'TOP SKILL · ${summary.topSkill!.toUpperCase()}',
                  style: crt.uiType.copyWith(color: crt.fgBright),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.summary});
  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    switch (summary.status) {
      case WeeklySummaryStatus.ok:
        final body = summary.body ?? '';
        return TypewriterText(
          // Stable key per week so swiping back doesn't replay clicks.
          key: ValueKey('week-${summary.weekStartDate.toIso8601String()}'),
          text: '> $body',
          style: crt.bodyType,
        );
      case WeeklySummaryStatus.pending:
        return Text(
          '> SYNTHESIS PENDING.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        );
      case WeeklySummaryStatus.empty:
        return Text(
          '> NO ACTIVITY THIS WEEK.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        );
      case WeeklySummaryStatus.failed:
        return Text(
          '> SYNTHESIST OFFLINE.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        );
    }
  }
}
