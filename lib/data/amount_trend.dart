import "package:decimal/decimal.dart";

/// A dated amount whose decimal value is retained independently of chart pixels.
class AmountTrendPoint {
  final DateTime date;
  final Decimal amount;

  const AmountTrendPoint(this.date, this.amount);
}

/// A signed ledger movement, including transfers and balance adjustments.
typedef TrendMovement = ({DateTime date, Decimal amount});

/// Local calendar boundaries, capped at now; historical points end each period.
/// Date constructors deliberately avoid fixed-duration month and DST arithmetic.
List<DateTime> trendAnchors({
  required DateTime from,
  required DateTime to,
  required DateTime now,
  required bool monthly,
}) {
  final DateTime end = to.isBefore(now) ? to : now;
  if (end.isBefore(from)) return [];
  final List<DateTime> result = [];
  DateTime cursor = DateTime(from.year, from.month, monthly ? 1 : from.day);
  while (!cursor.isAfter(end)) {
    final DateTime next = monthly
        ? DateTime(cursor.year, cursor.month + 1)
        : DateTime(cursor.year, cursor.month, cursor.day + 1);
    result.add(
      next.isAfter(end) ? end : next.subtract(const Duration(microseconds: 1)),
    );
    cursor = next;
  }
  return result;
}

/// Reconstructs balances from the complete ledger, retaining the opening balance.
List<AmountTrendPoint> balanceTrend(
  Iterable<TrendMovement> movements,
  List<DateTime> anchors,
) {
  final List<TrendMovement> sorted = movements.toList()
    ..sort((a, b) => a.date.compareTo(b.date));
  int cursor = 0;
  Decimal balance = Decimal.zero;
  return anchors.map((anchor) {
    while (cursor < sorted.length && !sorted[cursor].date.isAfter(anchor)) {
      balance += sorted[cursor].amount;
      cursor++;
    }
    return AmountTrendPoint(anchor, balance);
  }).toList();
}

/// Daily spending, with explicit zeroes for days without expenses.
List<AmountTrendPoint> dailySpendingTrend(
  Map<DateTime, Decimal> spending,
  List<DateTime> anchors,
) => anchors.map((anchor) {
  final DateTime day = DateTime(anchor.year, anchor.month, anchor.day);
  return AmountTrendPoint(anchor, spending[day] ?? Decimal.zero);
}).toList();
