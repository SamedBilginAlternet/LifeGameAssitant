import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/app/theme/crt_theme.dart';
import 'package:memoir_log/features/capture/presentation/providers/capture_providers.dart';
import 'package:memoir_log/features/capture/presentation/widgets/log_scaffold.dart';
import 'package:memoir_log/features/capture/presentation/widgets/terminal_widgets.dart';

class LogMealScreen extends ConsumerStatefulWidget {
  const LogMealScreen({super.key});

  @override
  ConsumerState<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends ConsumerState<LogMealScreen> {
  final _title = TextEditingController();
  final _proteinG = TextEditingController();
  final _calories = TextEditingController();
  String _type = 'lunch';

  @override
  void dispose() {
    _title.dispose();
    _proteinG.dispose();
    _calories.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    return LogScaffold(
      title: 'MEAL',
      onSave: () async {
        final title = _title.text.trim();
        if (title.isEmpty) {
          return ref.read(captureRepositoryProvider).logMeal(
                mealType: _type,
                title: '(unnamed meal)',
              );
        }
        return ref.read(captureRepositoryProvider).logMeal(
              mealType: _type,
              title: title,
              proteinG: num.tryParse(_proteinG.text.trim()),
              calories: int.tryParse(_calories.text.trim()),
            );
      },
      children: [
        _MealTypePicker(
          value: _type,
          onChanged: (v) {
            HapticFeedback.selectionClick();
            setState(() => _type = v);
          },
        ),
        const SizedBox(height: 16),
        TerminalField(controller: _title, label: 'TITLE', hint: 'tavuklu salata...'),
        const SizedBox(height: 16),
        TerminalField(
          controller: _proteinG,
          label: 'PROTEIN (g)',
          hint: '0',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 16),
        TerminalField(
          controller: _calories,
          label: 'CALORIES',
          hint: '0',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 24),
        Text(
          '> macros are optional. title is enough to make the meal\n  show up in the diary.',
          style: crt.bodyType.copyWith(color: crt.fgDim),
        ),
      ],
    );
  }
}

class _MealTypePicker extends StatelessWidget {
  const _MealTypePicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final crt = context.crt;
    Widget chip(String t, String label) {
      final selected = t == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: () => onChanged(t),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
            child: Text(
              selected ? '[> $label]' : '[ $label ]',
              style: crt.uiType.copyWith(
                color: selected ? crt.fgBright : crt.fgDim,
              ),
            ),
          ),
        ),
      );
    }

    return Wrap(
      children: [
        chip('breakfast', 'BREAKFAST'),
        chip('lunch', 'LUNCH'),
        chip('dinner', 'DINNER'),
        chip('snack', 'SNACK'),
      ],
    );
  }
}
