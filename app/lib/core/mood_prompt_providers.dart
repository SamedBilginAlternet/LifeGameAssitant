import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:memoir_log/core/mood_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'mood_prompt_enabled';

final moodPromptServiceProvider = Provider<MoodPromptService>((ref) {
  return MoodPromptService();
});

/// Persisted user setting. On first launch defaults to enabled — the
/// notification is the kind of thing users opt out of, not opt in.
class MoodPromptEnabledNotifier extends StateNotifier<bool> {
  MoodPromptEnabledNotifier(this._ref) : super(true) {
    _load();
  }

  final Ref _ref;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_prefsKey);
    if (stored == null) {
      // First launch — leave default ON, ensure the schedule exists
      // (the service is idempotent; ensure() is called by main on boot
      // too, but it's cheap to do here).
      await _apply(true);
      return;
    }
    state = stored;
    await _apply(stored);
  }

  Future<void> set(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
    await _apply(enabled);
  }

  Future<void> _apply(bool enabled) async {
    final svc = _ref.read(moodPromptServiceProvider);
    if (enabled) {
      await svc.requestPermissions();
      await svc.schedule();
    } else {
      await svc.cancel();
    }
  }
}

final moodPromptEnabledProvider =
    StateNotifierProvider<MoodPromptEnabledNotifier, bool>((ref) {
      return MoodPromptEnabledNotifier(ref);
    });
