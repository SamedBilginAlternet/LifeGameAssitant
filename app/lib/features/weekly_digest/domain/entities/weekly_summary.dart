enum WeeklySummaryStatus { pending, ok, empty, failed }

class WeeklySummary {
  const WeeklySummary({
    required this.weekStartDate,
    required this.weekEndDate,
    required this.status,
    this.body,
    this.topSkill,
    this.error,
  });

  final DateTime weekStartDate;
  final DateTime weekEndDate;
  final WeeklySummaryStatus status;
  final String? body;
  final String? topSkill;
  final String? error;
}
