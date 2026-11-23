import "package:flow/data/spending_statistics.dart";
import "package:flow/data/trend_axis_labels.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("current month includes zero-spending days through Nov 23", () {
    final days = elapsedSpendingDays(
      DateTime(2026, 11),
      DateTime(2026, 11, 30, 23),
      DateTime(2026, 11, 23, 9),
    );
    expect(days, 23);
    expect(dailySpendingAverage(230, days), 10);
  });
  test("past leap month, one day, future period and no spending", () {
    expect(
      elapsedSpendingDays(
        DateTime(2024, 2),
        DateTime(2024, 2, 29, 23),
        DateTime(2026),
      ),
      29,
    );
    expect(
      elapsedSpendingDays(
        DateTime(2026, 11, 23),
        DateTime(2026, 11, 23, 23),
        DateTime(2026, 11, 23, 10),
      ),
      1,
    );
    expect(
      elapsedSpendingDays(DateTime(2027), DateTime(2028), DateTime(2026)),
      0,
    );
    expect(dailySpendingAverage(0, 23), 0);
    expect(dailySpendingAverage(20, 0), 0);
  });
  test("axis keeps Nov 23 but drops nearby tick for phone widths", () {
    for (final width in [240.0, 300.0, 350.0, 700.0]) {
      final indices = trendAxisLabels(
        count: 23,
        width: width,
        labelWidth: (_) => 56,
      );
      expect(indices, contains(22));
      expect(indices, isNot(contains(21)));
      final positions =
          indices
              .map((i) => (width * i / 22 - 28).clamp(6.0, width - 62))
              .toList()
            ..sort();
      for (int i = 1; i < positions.length; i++) {
        expect(positions[i] - positions[i - 1], greaterThanOrEqualTo(66));
      }
    }
  });
  test("axis handles short months, single point and wide font", () {
    for (int count = 1; count <= 366; count++) {
      final ticks = trendAxisLabels(
        count: count,
        width: 260,
        labelWidth: (_) => 90,
      );
      expect(ticks, contains(count - 1));
      expect(ticks.length, lessThanOrEqualTo(3));
    }
    expect(
      trendAxisLabels(count: 0, width: 260, labelWidth: (_) => 30),
      isEmpty,
    );
  });
}
