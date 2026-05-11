import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn(OAuthProvider provider) async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(HapticFeedback.lightImpact());
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signInWithOAuth(provider, redirectTo: 'memoirlog://auth-callback');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Scaffold(
      backgroundColor: crt.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MEMOIR_LOG  v1.0', style: crt.dateHeaderType),
              const SizedBox(height: 48),
              Text('> AUTHENTICATION REQUIRED.', style: crt.bodyType),
              const SizedBox(height: 8),
              Text(
                '> select an identity provider:',
                style: crt.bodyType.copyWith(color: crt.fgDim),
              ),
              const SizedBox(height: 32),
              _TerminalButton(
                label: '[ SIGN IN WITH APPLE ]',
                onTap: _busy ? null : () => _signIn(OAuthProvider.apple),
              ),
              const SizedBox(height: 16),
              _TerminalButton(
                label: '[ SIGN IN WITH GOOGLE ]',
                onTap: _busy ? null : () => _signIn(OAuthProvider.google),
              ),
              const Spacer(),
              if (_busy)
                Text(
                  '> CONNECTING...',
                  style: crt.bodyType.copyWith(color: crt.fgDim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TerminalButton extends StatelessWidget {
  const _TerminalButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final disabled = onTap == null;
    final color = disabled ? crt.fgDim : crt.fgBright;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          boxShadow: disabled
              ? null
              : [BoxShadow(color: crt.glow, blurRadius: 12, spreadRadius: 1)],
        ),
        child: Text(label, style: crt.uiType.copyWith(color: color)),
      ),
    );
  }
}
