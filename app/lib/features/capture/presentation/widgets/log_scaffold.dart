import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/failure.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';

/// Shared chrome for the four focused log screens. Caller supplies the
/// title, the form body, and a save callback that returns the result.
class LogScaffold extends ConsumerStatefulWidget {
  const LogScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.successLine = '> SAVED. RETURNING...',
  });

  final String title;
  final List<Widget> children;
  final Future<Either<Failure, void>> Function() onSave;
  final String successLine;

  @override
  ConsumerState<LogScaffold> createState() => _LogScaffoldState();
}

class _LogScaffoldState extends ConsumerState<LogScaffold> {
  bool _busy = false;
  String? _statusLine;

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _statusLine = '> SAVING...';
    });
    unawaited(HapticFeedback.mediumImpact());
    final result = await widget.onSave();
    if (!mounted) return;
    result.match(
      (failure) {
        HapticFeedback.heavyImpact();
        setState(() {
          _busy = false;
          _statusLine = '> FAILED: ${failure.message.toUpperCase()}';
        });
      },
      (_) {
        HapticFeedback.mediumImpact();
        setState(() {
          _busy = false;
          _statusLine = widget.successLine;
        });
        Future<void>.delayed(const Duration(milliseconds: 600), () {
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
                  Text(widget.title, style: crt.dateHeaderType),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: ListView(children: widget.children)),
              if (_statusLine != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _statusLine!,
                    style: crt.bodyType.copyWith(color: crt.fgDim),
                  ),
                ),
              TerminalButton(
                label: _busy ? '[ SAVING... ]' : '[ SAVE ]',
                onTap: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
