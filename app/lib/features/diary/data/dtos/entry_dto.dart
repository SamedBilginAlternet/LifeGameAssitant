import 'package:memoir_log/features/diary/domain/entities/entry.dart';

/// Wire-format mirror of the entries row. Lives in data/ — the domain
/// Entry never sees a Map.
class EntryDto {
  const EntryDto({
    required this.id,
    required this.userId,
    required this.localDate,
    required this.status,
    required this.generatedAt,
    this.body,
    this.topSkill,
    this.model,
    this.stats,
  });

  final String id;
  final String userId;
  final String localDate; // YYYY-MM-DD
  final String status;
  final DateTime generatedAt;
  final String? body;
  final String? topSkill;
  final String? model;
  final Map<String, dynamic>? stats;

  factory EntryDto.fromJson(Map<String, dynamic> json) {
    return EntryDto(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      localDate: json['local_date'] as String,
      status: (json['status'] as String?) ?? 'failed',
      body: json['body'] as String?,
      topSkill: json['top_skill'] as String?,
      model: json['model'] as String?,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      stats: json['stats_json'] as Map<String, dynamic>?,
    );
  }

  Entry toEntity() {
    return Entry(
      id: id,
      localDate: DateTime.parse(localDate),
      body: body,
      topSkill: TopSkillX.fromString(topSkill),
      status: EntryStatusX.fromString(status),
      generatedAt: generatedAt,
      model: model,
      stats: stats,
    );
  }
}
