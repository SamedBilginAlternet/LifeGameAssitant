import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/supabase_providers.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _busy = false;
  String? _statusLine;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _signInOAuth(OAuthProvider provider) async {
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

  Future<void> _signInWithPassword() async {
    if (_busy) return;
    final email = _emailCtl.text.trim();
    final password = _passwordCtl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _statusLine = '> EMAIL + PASSWORD REQUIRED');
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '> AUTHENTICATING...';
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      await ref
          .read(supabaseClientProvider)
          .auth
          .signInWithPassword(email: email, password: password);
      // The router redirects on auth state change — nothing else to do here.
    } on AuthException catch (e) {
      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _statusLine = '> FAILED: ${e.message.toUpperCase()}');
      }
    } catch (e) {
      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _statusLine = '> FAILED: ${e.toString().toUpperCase()}');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signUpWithPassword() async {
    if (_busy) return;
    final email = _emailCtl.text.trim();
    final password = _passwordCtl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _statusLine = '> EMAIL + PASSWORD REQUIRED');
      return;
    }
    setState(() {
      _busy = true;
      _statusLine = '> CREATING ACCOUNT...';
    });
    unawaited(HapticFeedback.lightImpact());
    try {
      final res = await ref
          .read(supabaseClientProvider)
          .auth
          .signUp(email: email, password: password);
      if (!mounted) return;
      if (res.session != null) {
        // Email confirmation disabled — we're already signed in.
        return;
      }
      setState(
        () => _statusLine =
            '> CHECK INBOX TO CONFIRM, OR DISABLE CONFIRMATION IN SUPABASE',
      );
    } on AuthException catch (e) {
      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _statusLine = '> FAILED: ${e.message.toUpperCase()}');
      }
    } catch (e) {
      if (mounted) {
        unawaited(HapticFeedback.heavyImpact());
        setState(() => _statusLine = '> FAILED: ${e.toString().toUpperCase()}');
      }
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MEMOIR_LOG  v1.0', style: crt.dateHeaderType),
              const SizedBox(height: 32),
              Text('> AUTHENTICATION REQUIRED.', style: crt.bodyType),
              const SizedBox(height: 24),

              // Email + password — top of the list because it's the fastest
              // demo path (no provider setup needed beyond enabling Email
              // in the Supabase dashboard).
              TerminalField(
                controller: _emailCtl,
                label: 'EMAIL',
                hint: 'admin@demo.local',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _PasswordField(controller: _passwordCtl),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _TerminalButton(
                      label: '[ SIGN IN ]',
                      onTap: _busy ? null : _signInWithPassword,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TerminalButton(
                      label: '[ SIGN UP ]',
                      onTap: _busy ? null : _signUpWithPassword,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              Text(
                '> or sign in via identity provider:',
                style: crt.bodyType.copyWith(color: crt.fgDim),
              ),
              const SizedBox(height: 16),
              _TerminalButton(
                label: '[ SIGN IN WITH APPLE ]',
                onTap: _busy ? null : () => _signInOAuth(OAuthProvider.apple),
              ),
              const SizedBox(height: 12),
              _TerminalButton(
                label: '[ SIGN IN WITH GOOGLE ]',
                onTap: _busy ? null : () => _signInOAuth(OAuthProvider.google),
              ),

              const SizedBox(height: 24),
              if (_statusLine != null)
                Text(
                  _statusLine!,
                  style: crt.bodyType.copyWith(color: crt.fgDim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  const _PasswordField({required this.controller});
  final TextEditingController controller;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('> PASSWORD', style: crt.uiType.copyWith(color: crt.fgDim)),
            const Spacer(),
            InkWell(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Text(
                _obscure ? '[ SHOW ]' : '[ HIDE ]',
                style: crt.uiType.copyWith(color: crt.fgDim),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: widget.controller,
          obscureText: _obscure,
          style: crt.bodyType,
          cursorColor: crt.fgBright,
          decoration: InputDecoration(
            hintText: 'admin',
            hintStyle: crt.bodyType.copyWith(color: crt.fgGhost),
            counterText: '',
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: crt.fgDim),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: crt.fgBright),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: crt.fgDim),
            ),
          ),
        ),
      ],
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
        child: Text(
          label,
          style: crt.uiType.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
