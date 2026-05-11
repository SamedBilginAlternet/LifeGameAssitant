import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/supabase_providers.dart';

/// Plays the CRT boot sequence on cold start, then routes to the
/// timeline (the router redirect kicks the user to /login if they're
/// not signed in yet). Lasts ~2.4s — the same beat the landing page
/// boot hero uses.
///
/// On reduced-motion this collapses to the final frame and immediately
/// pushes forward.
class BootScreen extends ConsumerStatefulWidget {
  const BootScreen({super.key});

  @override
  ConsumerState<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends ConsumerState<BootScreen> {
  static const _lines = <String>[
    '> CHECKING STORAGE........... OK',
    '> CONNECTING TO SUPABASE..... OK',
    '> SYNCING ENTRIES............ OK',
    '> NARRATOR LINK.............. ONLINE',
    '> READY.',
  ];

  int _visibleLines = 0;
  Timer? _lineTimer;
  Timer? _exitTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startSequence());
  }

  void _startSequence() {
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced) {
      setState(() => _visibleLines = _lines.length);
      _scheduleExit(const Duration(milliseconds: 250));
      return;
    }
    // 400 ms per line: enough to read, less than a second of dead time
    // between lines.
    _lineTimer = Timer.periodic(const Duration(milliseconds: 400), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_visibleLines >= _lines.length) {
        t.cancel();
        _scheduleExit(const Duration(milliseconds: 700));
        return;
      }
      setState(() => _visibleLines++);
    });
  }

  void _scheduleExit(Duration delay) {
    _exitTimer = Timer(delay, () {
      if (!mounted || _navigated) return;
      _navigated = true;
      final user = ref.read(currentUserProvider);
      context.go(user == null ? '/login' : '/timeline');
    });
  }

  @override
  void dispose() {
    _lineTimer?.cancel();
    _exitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Scaffold(
      backgroundColor: crt.bgCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MEMOIR_LOG  v1.0  BOOT', style: crt.dateHeaderType),
              const SizedBox(height: 32),
              for (var i = 0; i < _visibleLines; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _BootLine(
                    text: _lines[i],
                    isLast: i == _lines.length - 1,
                  ),
                ),
              const Spacer(),
              if (_visibleLines >= _lines.length)
                Text(
                  '> SCROLL FOR TRANSMISSION ▼',
                  style: crt.bodyType.copyWith(color: crt.fgDim),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BootLine extends StatefulWidget {
  const _BootLine({required this.text, required this.isLast});
  final String text;
  final bool isLast;

  @override
  State<_BootLine> createState() => _BootLineState();
}

class _BootLineState extends State<_BootLine> {
  bool _cursorOn = true;
  Timer? _blink;

  @override
  void initState() {
    super.initState();
    if (widget.isLast) {
      _blink = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (mounted) setState(() => _cursorOn = !_cursorOn);
      });
    }
  }

  @override
  void dispose() {
    _blink?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final showCursor = widget.isLast && _cursorOn;
    return Text(
      showCursor ? '${widget.text}_' : widget.text,
      style: crt.uiType.copyWith(color: crt.fgBright),
    );
  }
}
