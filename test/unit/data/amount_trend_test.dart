import "package:decimal/decimal.dart";
import "package:flow/data/amount_trend.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("decimal accumulation retains fractions and opening balances", () {
    final points = balanceTrend(
      [
        (date: DateTime(2026, 1, 1), amount: Decimal.parse("1000.12345678")),
        (date: DateTime(2026, 2, 1), amount: Decimal.parse("-0.1")),
        (date: DateTime(2026, 2, 2), amount: Decimal.parse("-0.2")),
      ],
      [DateTime(2026, 2, 2), DateTime(2026, 2, 3)],
    );
    expect(points.first.amount.toString(), "999.82345678");
    expect(points.last.amount, points.first.amount);
  });

  test("month-end anchors respect leap years and unfinished months", () {
    final anchors = trendAnchors(
      from: DateTime(2024, 1, 15),
      to: DateTime(2024, 12, 31),
      now: DateTime(2024, 3, 10, 12),
      monthly: true,
    );
    expect(anchors.length, 3);
    expect(
      anchors[0],
      DateTime(2024, 2).subtract(const Duration(microseconds: 1)),
    );
    expect(
      anchors[1],
      DateTime(2024, 3).subtract(const Duration(microseconds: 1)),
    );
    expect(anchors.last, DateTime(2024, 3, 10, 12));
  });

  test("daily anchors include both endpoints, but no future days", () {
    final anchors = trendAnchors(
      from: DateTime(2026, 11, 19),
      to: DateTime(2026, 11, 30),
      now: DateTime(2026, 11, 20, 8),
      monthly: false,
    );
    expect(anchors.length, 2);
    final points = dailySpendingTrend({
      DateTime(2026, 11, 19): Decimal.parse("0.3"),
    }, anchors);
    expect(points.map((p) => p.amount.toString()), ["0.3", "0"]);
    expect(
      trendAnchors(
        from: DateTime(2027),
        to: DateTime(2028),
        now: DateTime(2026),
        monthly: false,
      ),
      isEmpty,
    );
  });

  test("negative balances, transfer movements and boundary times survive", () {
    final end = DateTime(2026, 3).subtract(const Duration(microseconds: 1));
    final points = balanceTrend(
      [
        (
          date: DateTime(2026, 2, 28, 23, 59, 59, 999),
          amount: Decimal.parse("-12.345"),
        ),
        (date: DateTime(2026, 3), amount: Decimal.parse("100")),
      ],
      [end, DateTime(2026, 3)],
    );
    expect(points.first.amount.toString(), "-12.345");
    expect(points.last.amount.toString(), "87.655");
  });
}
