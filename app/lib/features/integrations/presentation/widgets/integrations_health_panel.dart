import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/integrations/domain/entities/integration_health.dart';
import 'package:memoir_log/features/integrations/presentation/providers/integrations_providers.dart';

/// One row per known poller. Status chip + last-run timestamp.
/// Designed to live below the skill tree on the STATUS screen, so the
/// user has both XP and infrastructure health on one page.
class IntegrationsHealthPanel extends ConsumerWidget {
  const IntegrationsHealthPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    final snap = ref.watch(integrationsHealthProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('INTEGRATIONS', style: crt.dateHeaderType.copyWith(color: crt.fgDim)),
            const SizedBox(width: 12),
            Expanded(child: Container(height: 1, color: crt.fgGhost)),
          ],
        ),
        const SizedBox(height: 8),
        snap.when(
          loading: () => Text('> CHECKING...', style: crt.bodyType.copyWith(color: crt.fgDim)),
          error: (e, _) => Text(
            '> ERROR: ${e.toString().toUpperCase()}',
            style: crt.bodyType.copyWith(color: crt.fgDim),
          ),
          data: (either) => either.fold(
            (failure) => Text(
              '> ERROR: ${failure.message.toUpperCase()}',
              style: crt.bodyType.copyWith(color: crt.fgDim),
            ),
            (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final h in rows) _HealthRow(health: h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.health});
  final IntegrationHealth health;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final color = switch (health.status) {
      IntegrationHealthStatus.ok => crt.fgBright,
      IntegrationHealthStatus.stale => crt.fgDim,
      IntegrationHealthStatus.failed => crt.fgDim,
      IntegrationHealthStatus.never => crt.fgGhost,
    };
    final ts = health.lastRunAt;
    final tsLabel = ts == null
        ? '—'
        : DateFormat('HH:mm  dd-MMM').format(ts.toLocal()).toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 130,
                child: Text(
                  health.displayName,
                  style: crt.uiType.copyWith(color: color),
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '[${health.status.label}]',
                  style: crt.uiType.copyWith(color: color),
                ),
              ),
              Expanded(
                child: Text(
                  tsLabel,
                  style: crt.uiType.copyWith(color: crt.fgDim),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          if (health.status == IntegrationHealthStatus.failed && health.error != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2),
              child: Text(
                '· ${health.error}',
                style: crt.uiType.copyWith(color: crt.fgDim),
              ),
            ),
        ],
      ),
    );
  }
}
