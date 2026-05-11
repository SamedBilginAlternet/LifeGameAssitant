import 'package:health/health.dart';

/// Thin wrapper over the `health` package so the repository can stay
/// agnostic of plugin specifics. `health` only supports iOS + Android;
/// callers should already handle UnsupportedError gracefully (the
/// FitnessSyncRepository does).
class HealthDataSource {
  HealthDataSource({Health? health}) : _health = health ?? Health();

  final Health _health;
  bool _configured = false;

  static const _types = <HealthDataType>[
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    return await _health.requestAuthorization(_types);
  }

  /// Returns total steps recorded between [start] and [end]. Null if the
  /// platform has no data (e.g. simulator) or read access wasn't
  /// granted.
  Future<int?> stepsBetween(DateTime start, DateTime end) async {
    await _ensureConfigured();
    return _health.getTotalStepsInInterval(start, end);
  }

  /// Sums ACTIVE_ENERGY_BURNED points between [start] and [end] in
  /// kilocalories. Returns null when no data is available.
  Future<double?> activeKcalBetween(DateTime start, DateTime end) async {
    await _ensureConfigured();
    final points = await _health.getHealthDataFromTypes(
      types: const [HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: start,
      endTime: end,
    );
    if (points.isEmpty) return null;
    var total = 0.0;
    for (final p in points) {
      final v = p.value;
      if (v is NumericHealthValue) {
        total += v.numericValue.toDouble();
      }
    }
    return total;
  }
}
