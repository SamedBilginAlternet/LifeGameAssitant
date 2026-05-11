import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';

/// "ADD ENTRY" — routes to the right focused log screen.
class LogPickerScreen extends StatelessWidget {
  const LogPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    void go(String path) {
      HapticFeedback.lightImpact();
      context.push(path);
    }

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
                    onPressed: () => context.pop(),
                    icon: Text(
                      '[<]',
                      style: crt.uiType.copyWith(color: crt.fgBright),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('ADD TO TODAY', style: crt.dateHeaderType),
                ],
              ),
              const SizedBox(height: 24),
              TerminalButton(
                label: '[ QUICK · MOOD/PROTEIN/DE/NOTE ]',
                onTap: () => go('/capture'),
              ),
              const SizedBox(height: 12),
              TerminalButton(
                label: '[ MEAL    · log a meal ]',
                onTap: () => go('/log/meal'),
              ),
              const SizedBox(height: 12),
              TerminalButton(
                label: '[ WORKOUT · log a session ]',
                onTap: () => go('/log/workout'),
              ),
              const SizedBox(height: 12),
              TerminalButton(
                label: '[ MOVIE   · what you watched ]',
                onTap: () => go('/log/movie'),
              ),
              const SizedBox(height: 12),
              TerminalButton(
                label: '[ RIDE    · CF Moto 250NK ]',
                onTap: () => go('/log/ride'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
