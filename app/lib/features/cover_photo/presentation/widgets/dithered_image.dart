import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';

/// Renders a [ui.Image] through the 1-bit Bayer dither fragment shader.
///
/// Falls back to plain greyscale if the shader fails to compile (older
/// devices, simulator quirks). The cover photo is decorative — losing
/// the dither pass should never block the page from rendering.
class DitheredImage extends StatefulWidget {
  const DitheredImage({
    super.key,
    required this.image,
    this.aspectRatio = 16 / 9,
  });

  final ui.Image image;
  final double aspectRatio;

  @override
  State<DitheredImage> createState() => _DitheredImageState();
}

class _DitheredImageState extends State<DitheredImage> {
  ui.FragmentProgram? _program;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final program = await ui.FragmentProgram.fromAsset('shaders/dither.frag');
      if (mounted) setState(() => _program = program);
    } catch (_) {
      // Leave _program null — paint() falls back to plain image.
    }
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: CustomPaint(
        painter: _DitherPainter(
          program: _program,
          image: widget.image,
          tint: crt.fgBright,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _DitherPainter extends CustomPainter {
  _DitherPainter({
    required this.program,
    required this.image,
    required this.tint,
  });

  final ui.FragmentProgram? program;
  final ui.Image image;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    final program = this.program;
    if (program == null) {
      // Fallback: draw the source image with a colour filter biased
      // toward the active tint so it doesn't look out of place against
      // the CRT chrome.
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(tint.withValues(alpha: 0.85), BlendMode.modulate);
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Offset.zero & size,
        paint,
      );
      return;
    }

    final shader = program.fragmentShader();
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, tint.r)
      ..setFloat(3, tint.g)
      ..setFloat(4, tint.b)
      ..setFloat(5, tint.a)
      ..setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _DitherPainter old) =>
      old.program != program ||
      old.image != image ||
      old.tint != tint;
}

/// Convenience: decode encoded image bytes into a [ui.Image].
Future<ui.Image> decodeImageBytes(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
