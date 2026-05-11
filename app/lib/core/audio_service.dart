import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Centralized SFX playback. Single AudioPlayer instance per sample,
/// preloaded once on first use so the first key-click doesn't pay a
/// disk-read latency.
///
/// Per docs/DESIGN.md the volume is capped at -12 dB (0.25 amplitude
/// in the WAV files themselves). The toggle lives in [audioEnabledProvider].
class AudioService {
  AudioService();

  final Map<String, AudioPlayer> _players = {};

  Future<AudioPlayer> _player(String asset) async {
    final cached = _players[asset];
    if (cached != null) return cached;
    final p = AudioPlayer();
    await p.setReleaseMode(ReleaseMode.stop);
    await p.setSource(AssetSource(asset));
    _players[asset] = p;
    return p;
  }

  Future<void> _play(String asset) async {
    final p = await _player(asset);
    await p.stop();
    await p.resume();
  }

  Future<void> click() => _play('audio/key-click.wav');
  Future<void> powerOn() => _play('audio/power-on.wav');
  Future<void> confirm() => _play('audio/confirm.wav');
  Future<void> error() => _play('audio/error.wav');

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}

/// User-controlled audio toggle. Default ON. Persistence to a profile
/// row lands when Phase 2 settings persistence is wired.
final audioEnabledProvider = StateProvider<bool>((ref) => true);

final audioServiceProvider = Provider<AudioService>((ref) {
  final svc = AudioService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Convenience: play a click only when audio is enabled. Use this from
/// widgets so the toggle is honored without per-call branching.
extension AudioServiceGated on AudioService {
  Future<void> clickIfEnabled(WidgetRef ref) async {
    if (!ref.read(audioEnabledProvider)) return;
    await click();
  }
}
