import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';

void main() {
  group('CrtTheme', () {
    test('amber and phosphor expose distinct foreground colors', () {
      final amber = CrtTheme.amber();
      final phosphor = CrtTheme.phosphor();
      expect(amber.fgBright, isNot(equals(phosphor.fgBright)));
    });

    test('lerp halfway interpolates the foreground color', () {
      final amber = CrtTheme.amber();
      final phosphor = CrtTheme.phosphor();
      final mid = amber.lerp(phosphor, 0.5);
      expect(mid.fgBright, isNot(equals(amber.fgBright)));
      expect(mid.fgBright, isNot(equals(phosphor.fgBright)));
    });

    testWidgets('BuildContext.crt resolves the active extension',
        (tester) async {
      late CrtTheme resolved;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: <ThemeExtension<dynamic>>[CrtTheme.amber()],
          ),
          home: Builder(
            builder: (context) {
              resolved = context.crt;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolved.fgBright, const Color(0xFFFFB000));
    });
  });
}
