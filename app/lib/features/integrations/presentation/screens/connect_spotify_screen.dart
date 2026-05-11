import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/env.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';
import 'package:memoir_log/features/integrations/presentation/providers/integrations_providers.dart';

class ConnectSpotifyScreen extends ConsumerStatefulWidget {
  const ConnectSpotifyScreen({super.key});

  @override
  ConsumerState<ConnectSpotifyScreen> createState() =>
      _ConnectSpotifyScreenState();
}

class _ConnectSpotifyScreenState extends ConsumerState<ConnectSpotifyScreen> {
  bool _busy = false;
  String? _statusLine;

  Future<void> _connect() async {
    if (!Env.spotifyConfigured) {
      setState(() => _statusLine = '> SPOTIFY_CLIENT_ID NOT CONFIGURED');
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '> AWAITING SPOTIFY GRANT...';
    });
    unawaited(HapticFeedback.mediumImpact());

    final repo = ref.read(integrationsRepositoryProvider);
    final result = await repo.connectSpotify();

    if (!mounted) return;

    result.match(
      (failure) {
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _statusLine = '> FAILED: ${failure.message.toUpperCase()}';
        });
      },
      (integration) {
        HapticFeedback.mediumImpact();
        setState(() {
          _busy = false;
          _statusLine = '> CONNECTED AS ${integration.userId ?? "unknown"}';
        });
        ref.invalidate(spotifyIntegrationProvider);
        Future<void>.delayed(const Duration(milliseconds: 800), () {
          if (mounted) context.pop();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
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
                    onPressed: _busy ? null : () => context.pop(),
                    icon: Text(
                      '[<]',
                      style: crt.uiType.copyWith(color: crt.fgBright),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('CONNECT SPOTIFY', style: crt.dateHeaderType),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '> a system browser will open to spotify.\n'
                '> approve the request to share your\n'
                '> recently-played tracks.',
                style: crt.bodyType.copyWith(color: crt.fgDim),
              ),
              const Spacer(),
              if (_statusLine != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _statusLine!,
                    style: crt.bodyType.copyWith(color: crt.fgDim),
                  ),
                ),
              TerminalButton(
                label: _busy ? '[ AWAITING GRANT... ]' : '[ CONNECT ]',
                onTap: _busy ? null : _connect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
