import 'package:flutter/material.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';

/// Material [ThemeData] hosts that carry our [CrtTheme] extension.
/// The dark theme is the only theme — there is no light mode. The CRT is
/// always on.
ThemeData buildAmberTheme() => _buildTheme(CrtTheme.amber());

ThemeData buildPhosphorTheme() => _buildTheme(CrtTheme.phosphor());

ThemeData _buildTheme(CrtTheme crt) {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: crt.bgCanvas,
    canvasColor: crt.bgCanvas,
    colorScheme: base.colorScheme.copyWith(
      surface: crt.bgSurface,
      primary: crt.fgBright,
      onPrimary: crt.bgCanvas,
      onSurface: crt.fgBright,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: crt.fgBright,
      displayColor: crt.fgBright,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: crt.fgBright,
      selectionColor: crt.fgBright.withValues(alpha: 0.25),
      selectionHandleColor: crt.fgBright,
    ),
    extensions: <ThemeExtension<dynamic>>[crt],
  );
}
