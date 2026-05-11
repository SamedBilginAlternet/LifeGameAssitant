import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/app/theme/scanline_overlay.dart';
import 'package:memoir_log/app/theme/theme_provider.dart';
import 'package:memoir_log/core/audio_service.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/integrations/presentation/providers/integrations_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    final palette = ref.watch(crtPaletteProvider);
    final scanlines = ref.watch(scanlinesEnabledProvider);
    final audio = ref.watch(audioEnabledProvider);

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
                    icon: Text(
                      '[<]',
                      style: crt.uiType.copyWith(color: crt.fgBright),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('SETTINGS', style: crt.dateHeaderType),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionHeader('DISPLAY'),
              _PaletteRow(
                value: palette,
                onChanged: (next) {
                  HapticFeedback.selectionClick();
                  ref.read(crtPaletteProvider.notifier).state = next;
                },
              ),
              const SizedBox(height: 16),
              _ToggleRow(
                label: 'SCANLINES',
                value: scanlines,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  ref.read(scanlinesEnabledProvider.notifier).state = v;
                },
              ),
              const SizedBox(height: 32),
              const _SectionHeader('INTEGRATIONS'),
              _GithubRow(),
              _SpotifyRow(),
              const SizedBox(height: 32),
              const _SectionHeader('AUDIO'),
              _ToggleRow(
                label: 'CLICK TRACK + SFX',
                value: audio,
                onChanged: (v) {
                  HapticFeedback.selectionClick();
                  ref.read(audioEnabledProvider.notifier).state = v;
                  if (v) ref.read(audioServiceProvider).confirm();
                },
              ),
              const Spacer(),
              const _SectionHeader('SESSION'),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  unawaited(HapticFeedback.heavyImpact());
                  await ref.read(supabaseClientProvider).auth.signOut();
                  if (context.mounted) context.go('/login');
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '[ SIGN OUT ]',
                    style: crt.uiType.copyWith(color: crt.fgDim),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(label, style: crt.dateHeaderType.copyWith(color: crt.fgDim)),
          const SizedBox(width: 12),
          Expanded(child: Container(height: 1, color: crt.fgGhost)),
        ],
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text(label, style: crt.uiType.copyWith(color: crt.fgBright)),
            const Spacer(),
            Text(
              value ? '[ON ]' : '[OFF]',
              style: crt.uiType.copyWith(
                color: value ? crt.fgBright : crt.fgDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotifyRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    final integration = ref.watch(spotifyIntegrationProvider);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/integrations/spotify');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text('SPOTIFY', style: crt.uiType.copyWith(color: crt.fgBright)),
            const Spacer(),
            integration.when(
              loading: () =>
                  Text('...', style: crt.uiType.copyWith(color: crt.fgDim)),
              error: (_, __) =>
                  Text('[ERROR]', style: crt.uiType.copyWith(color: crt.fgDim)),
              data: (either) => either.match(
                (failure) => Text(
                  '[ERROR]',
                  style: crt.uiType.copyWith(color: crt.fgDim),
                ),
                (s) => Text(
                  s.connected ? '[@${s.userId}]' : '[CONNECT]',
                  style: crt.uiType.copyWith(
                    color: s.connected ? crt.fgBright : crt.fgDim,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GithubRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crt = context.crt;
    final integration = ref.watch(githubIntegrationProvider);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/integrations/github');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Text('GITHUB', style: crt.uiType.copyWith(color: crt.fgBright)),
            const Spacer(),
            integration.when(
              loading: () =>
                  Text('...', style: crt.uiType.copyWith(color: crt.fgDim)),
              error: (_, __) =>
                  Text('[ERROR]', style: crt.uiType.copyWith(color: crt.fgDim)),
              data: (either) => either.match(
                (failure) => Text(
                  '[ERROR]',
                  style: crt.uiType.copyWith(color: crt.fgDim),
                ),
                (g) => Text(
                  g.connected ? '[@${g.login}]' : '[CONNECT]',
                  style: crt.uiType.copyWith(
                    color: g.connected ? crt.fgBright : crt.fgDim,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({required this.value, required this.onChanged});
  final CrtPalette value;
  final ValueChanged<CrtPalette> onChanged;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    Widget chip(CrtPalette p, String label) {
      final selected = p == value;
      return InkWell(
        onTap: () => onChanged(p),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Text(
            selected ? '[> $label ]' : '[  $label ]',
            style: crt.uiType.copyWith(
              color: selected ? crt.fgBright : crt.fgDim,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('PALETTE', style: crt.uiType.copyWith(color: crt.fgBright)),
          const Spacer(),
          chip(CrtPalette.amber, 'AMBER   '),
          chip(CrtPalette.phosphor, 'PHOSPHOR'),
        ],
      ),
    );
  }
}
