import 'package:meta/meta.dart';

/// The diary's narrative output for one user-day. Pure Dart, no
/// framework imports — this is the domain entity, not the row.
@immutable
class Entry {
  const Entry({
    required this.id,
    required this.localDate,
    required this.body,
    required this.topSkill,
    required this.status,
    required this.generatedAt,
    this.model,
    this.stats,
  });

  final String id;
  final DateTime localDate;
  final String? body;
  final TopSkill? topSkill;
  final EntryStatus status;
  final DateTime generatedAt;
  final String? model;

  /// The aggregate that was sent to Groq to produce this entry. Shape
  /// matches supabase/functions/daily-summary/aggregate.ts. Used to
  /// render the stat strip under the body. Null on empty/failed days.
  final Map<String, dynamic>? stats;

  bool get isReady =>
      status == EntryStatus.ok && body != null && body!.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == id &&
          other.localDate == localDate &&
          other.body == body &&
          other.topSkill == topSkill &&
          other.status == status);

  @override
  int get hashCode => Object.hash(id, localDate, body, topSkill, status);
}

enum EntryStatus { ok, empty, failed }

enum TopSkill { logic, vitality, linguistics, culture, academic }

extension EntryStatusX on EntryStatus {
  static EntryStatus fromString(String raw) {
    switch (raw) {
      case 'ok':
        return EntryStatus.ok;
      case 'empty':
        return EntryStatus.empty;
      case 'failed':
        return EntryStatus.failed;
    }
    return EntryStatus.failed;
  }
}

extension TopSkillX on TopSkill {
  static TopSkill? fromString(String? raw) {
    if (raw == null) return null;
    switch (raw) {
      case 'logic':
        return TopSkill.logic;
      case 'vitality':
        return TopSkill.vitality;
      case 'linguistics':
        return TopSkill.linguistics;
      case 'culture':
        return TopSkill.culture;
      case 'academic':
        return TopSkill.academic;
    }
    return null;
  }

  String get label => switch (this) {
    TopSkill.logic => 'LOGIC',
    TopSkill.vitality => 'VITALITY',
    TopSkill.linguistics => 'LINGUISTICS',
    TopSkill.culture => 'CULTURE',
    TopSkill.academic => 'ACADEMIC',
  };
}
