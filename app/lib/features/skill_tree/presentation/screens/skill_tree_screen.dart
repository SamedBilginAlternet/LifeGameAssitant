import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/integrations/presentation/widgets/integrations_health_panel.dart';
import 'package:memoir_log/features/skill_tree/domain/entities/skill.dart';
import 'package:memoir_log/features/skill_tree/presentation/providers/skill_tree_providers.dart';
import 'package:memoir_log/features/skill_tree/presentation/widgets/radial_skill_tree.dart';

class SkillTreeScreen extends ConsumerWidget {
  const SkillTreeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    final snapshot = ref.watch(skillTreeSnapshotProvider);

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
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.pop();
                    },
                    icon: Text('[<]', style: crt.uiType.copyWith(color: crt.fgBright)),
                  ),
                  const SizedBox(width: 8),
                  Text('STATUS', style: crt.dateHeaderType),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '> rolling 30-day skill tree',
                style: crt.bodyType.copyWith(color: crt.fgDim),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      snapshot.when(
                        loading: () => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '> COMPUTING XP...',
                            style: crt.bodyType.copyWith(color: crt.fgDim),
                          ),
                        ),
                        error: (e, _) => Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            '> ERROR: ${e.toString().toUpperCase()}',
                            style: crt.bodyType.copyWith(color: crt.fgDim),
                          ),
                        ),
                        data: (either) => either.fold(
                          (failure) => Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              '> ERROR: ${failure.message.toUpperCase()}',
                              style: crt.bodyType.copyWith(color: crt.fgDim),
                            ),
                          ),
                          (snap) => _Body(snapshot: snap),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const IntegrationsHealthPanel(),
                      const SizedBox(height: 24),
                    ],
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

class _Body extends StatelessWidget {
  const _Body({required this.snapshot});
  final SkillTreeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Column(
      children: [
        RadialSkillTree(snapshot: snapshot),
        const SizedBox(height: 24),
        Container(height: 1, color: crt.fgGhost),
        const SizedBox(height: 12),
        Text(
          '> dominant: ${_labelFor(snapshot.dominant)}',
          style: crt.bodyType,
        ),
        const SizedBox(height: 8),
        for (final s in snapshot.stats)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    _labelFor(s.skill),
                    style: crt.uiType.copyWith(
                      color: s.skill == snapshot.dominant ? crt.fgBright : crt.fgDim,
                    ),
                  ),
                ),
                Text(
                  'LV ${s.level.toString().padLeft(2, '0')}'
                  '  ·  ${s.totalXp} XP',
                  style: crt.uiType.copyWith(color: crt.fgDim),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _labelFor(Skill s) => s.label;
}
