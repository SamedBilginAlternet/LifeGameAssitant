import 'package:flutter/material.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';

/// 8-bit progress bar built from filled (█) and empty (░) blocks. Snaps
/// to 16 cells. Renders block-by-block on first paint.
///
/// Over-target shows the trailing block as ▓ rather than overflowing,
/// so the eye still recognizes the bar as "done."
class PixelMeter extends StatelessWidget {
  const PixelMeter({
    super.key,
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
    this.cells = 16,
  });

  final String label;
  final num value;
  final num target;
  final String unit;
  final int cells;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final ratio = target == 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    final overTarget = target > 0 && value > target;
    final filled = (ratio * cells).round();

    final buf = StringBuffer();
    for (var i = 0; i < cells; i++) {
      if (i < filled - 1) {
        buf.write('█');
      } else if (i < filled) {
        buf.write(overTarget ? '▓' : '█');
      } else {
        buf.write('░');
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label.toUpperCase(),
              style: crt.uiType.copyWith(color: crt.fgDim),
            ),
          ),
          const SizedBox(width: 8),
          Text(buf.toString(), style: crt.statNumberType),
          const SizedBox(width: 8),
          Text(
            '${_format(value)}/${_format(target)} $unit'.toUpperCase(),
            style: crt.uiType.copyWith(color: crt.fgDim),
          ),
        ],
      ),
    );
  }

  String _format(num n) {
    if (n is int || n == n.roundToDouble()) return n.round().toString();
    return n.toStringAsFixed(1);
  }
}
