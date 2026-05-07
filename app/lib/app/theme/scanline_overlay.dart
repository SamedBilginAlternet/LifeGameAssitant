import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';

/// Toggleable in Settings. Default ON.
final scanlinesEnabledProvider = StateProvider<bool>((ref) => true);

/// Overlays the active page with a CRT scanline shader. Mounted by the
/// shell scaffold so it covers nav chrome too.
class ScanlineOverlay extends ConsumerStatefulWidget {
  const ScanlineOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ScanlineOverlay> createState() => _ScanlineOverlayState();
}

class _ScanlineOverlayState extends ConsumerState<ScanlineOverlay>
    with SingleTickerProviderStateMixin {
  ui.FragmentProgram? _program;
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      // Repaint at most once per frame.
      setState(() => _elapsed = d);
    })
      ..start();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/scanlines.frag');
      if (mounted) setState(() => _program = program);
    } catch (_) {
      // Shader compilation can fail on older devices. Fall back to no
      // overlay — the app still renders correctly without scanlines.
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(scanlinesEnabledProvider);
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    final program = _program;
    final crt = context.crt;

    if (!enabled || reducedMotion || program == null) {
      return widget.child;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: CustomPaint(
            painter: _ScanlinePainter(
              program: program,
              elapsed: _elapsed,
              opacity: crt.scanlineOpacity,
              tint: crt.fgBright,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _ScanlinePainter extends CustomPainter {
  _ScanlinePainter({
    required this.program,
    required this.elapsed,
    required this.opacity,
    required this.tint,
  });

  final ui.FragmentProgram program;
  final Duration elapsed;
  final double opacity;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, elapsed.inMicroseconds / Duration.microsecondsPerSecond)
      ..setFloat(3, opacity)
      ..setFloat(4, tint.r)
      ..setFloat(5, tint.g)
      ..setFloat(6, tint.b)
      ..setFloat(7, tint.a);
    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanlinePainter old) =>
      old.elapsed != elapsed ||
      old.opacity != opacity ||
      old.tint != tint;
}
