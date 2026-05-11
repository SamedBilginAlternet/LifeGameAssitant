import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';

/// Terminal-styled rectangular button. Shared by the capture and
/// settings screens so the look stays consistent without copy-paste.
class TerminalButton extends StatelessWidget {
  const TerminalButton({
    super.key,
    required this.label,
    this.onTap,
    this.glow = true,
  });

  final String label;
  final VoidCallback? onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    final disabled = onTap == null;
    final color = disabled ? crt.fgDim : crt.fgBright;
    return InkWell(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          boxShadow: disabled || !glow
              ? null
              : [BoxShadow(color: crt.glow, blurRadius: 12, spreadRadius: 1)],
        ),
        child: Text(label, style: crt.uiType.copyWith(color: color)),
      ),
    );
  }
}

/// Terminal-styled labelled input. Underline border, monospaced font,
/// cursor in the active fg color.
class TerminalField extends StatelessWidget {
  const TerminalField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.maxLength,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('> $label', style: crt.uiType.copyWith(color: crt.fgDim)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          style: crt.bodyType,
          cursorColor: crt.fgBright,
          decoration: InputDecoration(
            hintText: hint,
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
