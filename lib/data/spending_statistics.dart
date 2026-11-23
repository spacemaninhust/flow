/// Inclusive local calendar days, capped at today, independent of DST hours.
int elapsedSpendingDays(DateTime from, DateTime to, DateTime now) {
  final end = to.isBefore(now) ? to : now;
  if (end.isBefore(from)) return 0;
  final startDay = DateTime.utc(from.year, from.month, from.day);
  final endDay = DateTime.utc(end.year, end.month, end.day);
  return endDay.difference(startDay).inDays + 1;
}

/// Average includes days with zero spending and never divides by zero.
double dailySpendingAverage(double total, int days) =>
    days > 0 ? total / days : 0;
