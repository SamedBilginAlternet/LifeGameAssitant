import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Retro CRT design tokens. Lives as a [ThemeExtension] so widgets stay
/// decoupled from the active palette — switching from Amber to Phosphor
/// is a single provider write, not a widget rewrite.
@immutable
class CrtTheme extends ThemeExtension<CrtTheme> {
  const CrtTheme({
    required this.bgCanvas,
    required this.bgSurface,
    required this.fgBright,
    required this.fgDim,
    required this.fgGhost,
    required this.glow,
    required this.bodyType,
    required this.uiType,
    required this.dateHeaderType,
    required this.statNumberType,
    required this.scanlineOpacity,
  });

  /// Sunset CRT — the default. Warm amber phosphor on pure black.
  factory CrtTheme.amber() {
    const bright = Color(0xFFFFB000);
    return CrtTheme(
      bgCanvas: const Color(0xFF000000),
      bgSurface: const Color(0xFF0A0705),
      fgBright: bright,
      fgDim: const Color(0xFFA36F00),
      fgGhost: const Color(0xFF3D2A00),
      glow: bright.withValues(alpha: 0.18),
      bodyType: GoogleFonts.vt323(fontSize: 22, color: bright, height: 1.25),
      uiType: GoogleFonts.shareTechMono(fontSize: 14, color: bright),
      dateHeaderType: GoogleFonts.pressStart2p(fontSize: 11, color: bright),
      statNumberType: GoogleFonts.shareTechMono(
        fontSize: 18,
        color: bright,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      scanlineOpacity: 0.12,
    );
  }

  /// Phosphor — classic 1980s green-screen alt palette.
  factory CrtTheme.phosphor() {
    const bright = Color(0xFF00E676);
    return CrtTheme(
      bgCanvas: const Color(0xFF000000),
      bgSurface: const Color(0xFF02080A),
      fgBright: bright,
      fgDim: const Color(0xFF008A45),
      fgGhost: const Color(0xFF003319),
      glow: bright.withValues(alpha: 0.18),
      bodyType: GoogleFonts.vt323(fontSize: 22, color: bright, height: 1.25),
      uiType: GoogleFonts.shareTechMono(fontSize: 14, color: bright),
      dateHeaderType: GoogleFonts.pressStart2p(fontSize: 11, color: bright),
      statNumberType: GoogleFonts.shareTechMono(
        fontSize: 18,
        color: bright,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      scanlineOpacity: 0.10,
    );
  }

  final Color bgCanvas;
  final Color bgSurface;
  final Color fgBright;
  final Color fgDim;
  final Color fgGhost;
  final Color glow;
  final TextStyle bodyType;
  final TextStyle uiType;
  final TextStyle dateHeaderType;
  final TextStyle statNumberType;
  final double scanlineOpacity;

  @override
  CrtTheme copyWith({
    Color? bgCanvas,
    Color? bgSurface,
    Color? fgBright,
    Color? fgDim,
    Color? fgGhost,
    Color? glow,
    TextStyle? bodyType,
    TextStyle? uiType,
    TextStyle? dateHeaderType,
    TextStyle? statNumberType,
    double? scanlineOpacity,
  }) {
    return CrtTheme(
      bgCanvas: bgCanvas ?? this.bgCanvas,
      bgSurface: bgSurface ?? this.bgSurface,
      fgBright: fgBright ?? this.fgBright,
      fgDim: fgDim ?? this.fgDim,
      fgGhost: fgGhost ?? this.fgGhost,
      glow: glow ?? this.glow,
      bodyType: bodyType ?? this.bodyType,
      uiType: uiType ?? this.uiType,
      dateHeaderType: dateHeaderType ?? this.dateHeaderType,
      statNumberType: statNumberType ?? this.statNumberType,
      scanlineOpacity: scanlineOpacity ?? this.scanlineOpacity,
    );
  }

  @override
  CrtTheme lerp(ThemeExtension<CrtTheme>? other, double t) {
    if (other is! CrtTheme) return this;
    return CrtTheme(
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      fgBright: Color.lerp(fgBright, other.fgBright, t)!,
      fgDim: Color.lerp(fgDim, other.fgDim, t)!,
      fgGhost: Color.lerp(fgGhost, other.fgGhost, t)!,
      glow: Color.lerp(glow, other.glow, t)!,
      bodyType: TextStyle.lerp(bodyType, other.bodyType, t)!,
      uiType: TextStyle.lerp(uiType, other.uiType, t)!,
      dateHeaderType: TextStyle.lerp(dateHeaderType, other.dateHeaderType, t)!,
      statNumberType: TextStyle.lerp(statNumberType, other.statNumberType, t)!,
      scanlineOpacity: scanlineOpacity + (other.scanlineOpacity - scanlineOpacity) * t,
    );
  }
}

/// Sugar so widgets read theme tokens as `context.crt.fgBright` rather than
/// `Theme.of(context).extension<CrtTheme>()!.fgBright`.
extension CrtThemeContext on BuildContext {
  CrtTheme get crt => Theme.of(this).extension<CrtTheme>()!;
}
