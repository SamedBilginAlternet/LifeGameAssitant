enum VoiceNoteStatus { pending, ok, failed }

class CorrectionItem {
  const CorrectionItem({
    required this.original,
    required this.corrected,
    required this.note,
  });
  final String original;
  final String corrected;
  final String note;
}

class VoiceNote {
  const VoiceNote({
    required this.id,
    required this.localDate,
    required this.storagePath,
    required this.durationSec,
    required this.status,
    this.language,
    this.transcriptDe,
    this.transcriptEn,
    this.corrections = const [],
    this.error,
  });

  final String id;
  final DateTime localDate;
  final String storagePath;
  final int durationSec;
  final VoiceNoteStatus status;
  final String? language;
  final String? transcriptDe;
  final String? transcriptEn;
  final List<CorrectionItem> corrections;
  final String? error;
}
