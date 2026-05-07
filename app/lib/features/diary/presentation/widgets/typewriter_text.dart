import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/core/audio_service.dart';

/// Reveals [text] character-by-character with an optional 8-bit click
/// per char. Once revealed, a key never re-runs the animation — so
/// scrolling back through the timeline doesn't replay clicks for every
/// page. The "key" of the day is enough.
class TypewriterText extends ConsumerStatefulWidget {
  const TypewriterText({
    super.key,
    required this.text,
    required this.style,
    this.charsPerSecond = 28,
    this.cursor = '_',
    this.playClick = true,
  });

  final String text;
  final TextStyle style;
  final double charsPerSecond;
  final String cursor;
  final bool playClick;

  @override
  ConsumerState<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends ConsumerState<TypewriterText> {
  static final Set<String> _seenKeys = <String>{};

  Timer? _timer;
  int _shown = 0;
  bool _cursorOn = true;
  Timer? _cursorTimer;

  String get _identity => '${widget.key}_${widget.text.hashCode}';

  @override
  void initState() {
    super.initState();
    final alreadySeen = _seenKeys.contains(_identity);
    if (alreadySeen || MediaQuery.of(context).disableAnimations) {
      _shown = widget.text.length;
    } else {
      _scheduleNextChar();
    }
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _cursorOn = !_cursorOn);
    });
  }

  void _scheduleNextChar() {
    final perChar = Duration(milliseconds: (1000 / widget.charsPerSecond).round());
    _timer = Timer.periodic(perChar, (timer) {
      if (!mounted || _shown >= widget.text.length) {
        timer.cancel();
        if (mounted) {
          _seenKeys.add(_identity);
        }
        return;
      }
      setState(() => _shown++);
      if (widget.playClick && widget.text[_shown - 1] != ' ') {
        // Fire-and-forget — clicks must not block the typewriter pace.
        unawaited(ref.read(audioServiceProvider).clickIfEnabled(ref));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final shown = widget.text.substring(0, _shown);
    final inFlight = _shown < widget.text.length;
    final cursorChar = (inFlight || _cursorOn) ? widget.cursor : ' ';
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: shown),
          TextSpan(
            text: cursorChar,
            style: widget.style.copyWith(color: crt.fgBright),
          ),
        ],
      ),
    );
  }
}
