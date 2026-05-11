import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Thin wrapper over the `record` package that hides the AudioRecorder
/// lifecycle and exposes only the operations the repository needs.
/// Capped at 60 seconds — the diary page is not a podcasting tool.
class VoiceRecorder {
  VoiceRecorder({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _activePath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 96000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
    _activePath = path;
  }

  /// Stops recording and returns the local file. Caller is responsible
  /// for moving / uploading the bytes.
  Future<File?> stop() async {
    final returned = await _recorder.stop();
    final path = returned ?? _activePath;
    _activePath = null;
    if (path == null) return null;
    final file = File(path);
    return file.existsSync() ? file : null;
  }

  Future<void> cancel() async {
    await _recorder.cancel();
    _activePath = null;
  }

  Future<bool> isRecording() => _recorder.isRecording();

  void dispose() {
    _recorder.dispose();
  }
}
