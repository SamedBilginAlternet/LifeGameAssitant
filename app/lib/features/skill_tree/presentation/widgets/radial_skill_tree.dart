import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/skill_tree/domain/entities/skill.dart';

/// 5 nodes evenly distributed around a center point. Node radius scales
/// with level (capped) so the dominant skill visibly rises out of the
/// page.
class RadialSkillTree extends StatelessWidget {
  const RadialSkillTree({super.key, required this.snapshot});
  final SkillTreeSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _TreePainter(
          stats: snapshot.stats,
          dominant: snapshot.dominant,
          fgBright: crt.fgBright,
          fgDim: crt.fgDim,
          fgGhost: crt.fgGhost,
        ),
      ),
    );
  }
}

class _TreePainter extends CustomPainter {
  _TreePainter({
    required this.stats,
    required this.dominant,
    required this.fgBright,
    required this.fgDim,
    required this.fgGhost,
  });

  final List<SkillStats> stats;
  final Skill dominant;
  final Color fgBright;
  final Color fgDim;
  final Color fgGhost;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 56;

    final spokePaint = Paint()
      ..color = fgGhost
      ..strokeWidth = 1;
    final hubPaint = Paint()..color = fgDim;

    // Spokes from center to each node anchor.
    final positions = <Skill, Offset>{};
    for (var i = 0; i < stats.length; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / stats.length);
      final pos = Offset(
        center.dx + math.cos(angle) * outerRadius,
        center.dy + math.sin(angle) * outerRadius,
      );
      positions[stats[i].skill] = pos;
      canvas.drawLine(center, pos, spokePaint);
    }
    canvas.drawCircle(center, 4, hubPaint);

    // Nodes.
    for (final s in stats) {
      final pos = positions[s.skill]!;
      final isDominant = s.skill == dominant;
      final color = isDominant ? fgBright : fgDim;
      final r = 8 + math.min(s.level, 60) * 0.35;

      // Pixel-art square node — six 2-px squares forming an outer
      // shell around a 4px filled core. Cheaper than a real
      // pixel-art sprite and still reads as 8-bit.
      final shell = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawRect(Rect.fromCenter(center: pos, width: r * 2, height: r * 2), shell);
      canvas.drawRect(
        Rect.fromCenter(center: pos, width: r, height: r),
        Paint()..color = color,
      );

      // Label below the node.
      final tp = TextPainter(
        text: TextSpan(
          text: s.skill.label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx - tp.width / 2, pos.dy + r + 6));

      // Level under the label.
      final lvl = TextPainter(
        text: TextSpan(
          text: 'LV ${s.level.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: color,
            fontSize: 9,
            letterSpacing: 1.2,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      lvl.paint(canvas, Offset(pos.dx - lvl.width / 2, pos.dy + r + 22));
    }
  }

  @override
  bool shouldRepaint(covariant _TreePainter old) =>
      old.stats != stats || old.dominant != dominant;
}
