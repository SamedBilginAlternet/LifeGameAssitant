import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/capture/presentation/providers/capture_providers.dart';
import 'package:memoir_log/features/capture/presentation/widgets/log_scaffold.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';

class LogMovieScreen extends ConsumerStatefulWidget {
  const LogMovieScreen({super.key});

  @override
  ConsumerState<LogMovieScreen> createState() => _LogMovieScreenState();
}

class _LogMovieScreenState extends ConsumerState<LogMovieScreen> {
  final _title = TextEditingController();
  final _year = TextEditingController();
  String _medium = 'streaming';
  int _rating = 4;

  @override
  void dispose() {
    _title.dispose();
    _year.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return LogScaffold(
      title: 'MOVIE',
      onSave: () {
        final title = _title.text.trim();
        return ref.read(captureRepositoryProvider).logMovie(
              title: title.isEmpty ? '(untitled)' : title,
              releaseYear: int.tryParse(_year.text.trim()),
              rating: _rating,
              medium: _medium,
            );
      },
      children: [
        TerminalField(controller: _title, label: 'TITLE', hint: 'Blade Runner...'),
        const SizedBox(height: 16),
        TerminalField(
          controller: _year,
          label: 'YEAR (optional)',
          hint: '1982',
          keyboardType: TextInputType.number,
          maxLength: 4,
        ),
        const SizedBox(height: 16),
        Text('> MEDIUM', style: crt.uiType.copyWith(color: crt.fgDim)),
        const SizedBox(height: 4),
        Wrap(
          children: [
            for (final m in const ['cinema', 'streaming', 'tv'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _medium = m);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    child: Text(
                      _medium == m ? '[> ${m.toUpperCase()}]' : '[ ${m.toUpperCase()} ]',
                      style: crt.uiType.copyWith(
                        color: _medium == m ? crt.fgBright : crt.fgDim,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('> RATING  ${_rating.toString().padLeft(2)} / 5',
            style: crt.uiType.copyWith(color: crt.fgDim)),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _rating = i);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    i <= _rating ? '█' : '░',
                    style: crt.statNumberType.copyWith(
                      color: i <= _rating ? crt.fgBright : crt.fgDim,
                      fontSize: 28,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
