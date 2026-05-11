enum Skill { logic, vitality, linguistics, culture, academic }

extension SkillX on Skill {
  String get id => name;

  String get label => switch (this) {
    Skill.logic => 'LOGIC',
    Skill.vitality => 'VITALITY',
    Skill.linguistics => 'LINGUISTICS',
    Skill.culture => 'CULTURE',
    Skill.academic => 'ACADEMIC',
  };
}

class SkillStats {
  const SkillStats({
    required this.skill,
    required this.activityXp,
    required this.entryBonus,
  });

  final Skill skill;

  /// Rolling 30-day activity score, weighted per source.
  final int activityXp;

  /// Number of recent entries (last 30 days) where this was the
  /// `top_skill`. Each one adds 5 XP.
  final int entryBonus;

  int get totalXp => activityXp + entryBonus * 5;

  /// Pixel-tree level. Logarithmic so the early gains feel quick and
  /// the later ones feel earned. Capped at 99 so the UI never has to
  /// render three digits.
  int get level {
    final raw = (totalXp + 1).toDouble();
    final calc = (10 * (_log10(raw))).floor();
    return calc < 0 ? 0 : (calc > 99 ? 99 : calc);
  }
}

/// log10 without pulling dart:math into the entity. Inlined so the
/// entity stays a single import.
double _log10(double x) {
  // ln(x) / ln(10); ln10 ≈ 2.302585092994046
  return _ln(x) / 2.302585092994046;
}

/// Cheap natural-log approximation good to ~5 digits — fine for level
/// gates (we floor to int).
double _ln(double x) {
  if (x <= 0) return 0;
  // Range-reduce: ln(x) = k*ln2 + ln(m), where m in [1, 2).
  var k = 0;
  var m = x;
  while (m >= 2) {
    m /= 2;
    k++;
  }
  while (m < 1) {
    m *= 2;
    k--;
  }
  // ln(m) via series around 1: t = m - 1, ln(1+t) ≈ t - t²/2 + t³/3 - ...
  final t = m - 1;
  var sum = 0.0;
  var term = t;
  for (var n = 1; n <= 10; n++) {
    sum += term / n * (n.isOdd ? 1 : -1);
    term *= t;
  }
  return sum + k * 0.6931471805599453;
}

class SkillTreeSnapshot {
  const SkillTreeSnapshot({required this.stats, required this.dominant});
  final List<SkillStats> stats;
  final Skill dominant;
}
