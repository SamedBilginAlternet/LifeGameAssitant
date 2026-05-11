import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';
import 'package:memoir_log/features/integrations/presentation/providers/integrations_providers.dart';

class ConnectGithubScreen extends ConsumerStatefulWidget {
  const ConnectGithubScreen({super.key});

  @override
  ConsumerState<ConnectGithubScreen> createState() =>
      _ConnectGithubScreenState();
}

class _ConnectGithubScreenState extends ConsumerState<ConnectGithubScreen> {
  final _tokenCtl = TextEditingController();
  bool _busy = false;
  String? _statusLine;

  @override
  void dispose() {
    _tokenCtl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenCtl.text.trim();
    if (token.isEmpty) return;
    setState(() {
      _busy = true;
      _statusLine = '> VALIDATING TOKEN...';
    });
    HapticFeedback.mediumImpact();

    final repo = ref.read(integrationsRepositoryProvider);
    final result = await repo.connectGithub(token: token);

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
          _statusLine = '> CONNECTED AS @${integration.login ?? "unknown"}';
        });
        ref.invalidate(githubIntegrationProvider);
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
                  Text('CONNECT GITHUB', style: crt.dateHeaderType),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '> paste a personal access token with the\n> `read:user` and `public_repo` scopes.',
                style: crt.bodyType.copyWith(color: crt.fgDim),
              ),
              const SizedBox(height: 24),
              TerminalField(
                controller: _tokenCtl,
                label: 'TOKEN',
                hint: 'ghp_...',
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
                label: _busy ? '[ VALIDATING... ]' : '[ CONNECT ]',
                onTap: _busy ? null : _connect,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
