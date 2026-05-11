enum IntegrationHealthStatus { ok, stale, failed, never }

extension IntegrationHealthStatusX on IntegrationHealthStatus {
  String get label => switch (this) {
    IntegrationHealthStatus.ok => 'OK',
    IntegrationHealthStatus.stale => 'STALE',
    IntegrationHealthStatus.failed => 'FAILED',
    IntegrationHealthStatus.never => 'NEVER',
  };
}

class IntegrationHealth {
  const IntegrationHealth({
    required this.kind,
    required this.status,
    this.lastRunAt,
    this.error,
  });

  /// Stable id — `github_poll`, `spotify_poll`, etc. Mirrors the value
  /// the Edge Functions write to integration_runs.kind.
  final String kind;
  final IntegrationHealthStatus status;
  final DateTime? lastRunAt;
  final String? error;

  /// Friendly display label.
  String get displayName => switch (kind) {
    'github_poll' => 'GITHUB POLL',
    'spotify_poll' => 'SPOTIFY POLL',
    _ => kind.toUpperCase(),
  };
}
