import "package:decimal/decimal.dart";
import "package:fl_chart/fl_chart.dart";
import "package:flow/data/amount_trend.dart";
import "package:flow/data/money.dart";
import "package:flow/widgets/analytics/spending_heatmap.dart";
import "package:flow/theme/theme.dart";
import "package:flow/theme/color_themes/registry.dart";
import "package:flow/l10n/flow_localizations.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/widgets/stats/amount_trend_chart.dart";
import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";
// ignore: depend_on_referenced_packages
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
// ignore: depend_on_referenced_packages
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";

class _TestLocalizations extends LocalizationsDelegate<FlowLocalizations> {
  const _TestLocalizations();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<FlowLocalizations> load(Locale locale) =>
      SynchronousFuture(FlowLocalizations(const Locale("en")));

  @override
  bool shouldReload(covariant LocalizationsDelegate<FlowLocalizations> old) =>
      false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await LocalPreferences.initialize();
    await FlowLocalizations(const Locale("en")).load();
  });
  testWidgets("tap selects original decimal value and selection persists", (
    tester,
  ) async {
    final points = [
      AmountTrendPoint(DateTime(2026, 11, 19), Decimal.parse("12345.678901")),
      AmountTrendPoint(DateTime(2026, 11, 20), Decimal.parse("0.3")),
    ];
    AmountTrendPoint? selected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_TestLocalizations()],
        home: Scaffold(
          body: AmountTrendChart(
            points: points,
            currency: "CNY",
            onSelected: (point) => selected = point,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip("Previous point"));
    await tester.pumpAndSettle();
    expect(selected, points.first);
    expect(
      find.text(Money(12345.678901, "CNY").formattedExact),
      findsOneWidget,
    );
    final Rect chartRect = tester.getRect(find.byType(LineChart));
    await tester.tapAt(Offset(chartRect.right - 2, chartRect.top + 165));
    await tester.pumpAndSettle();
    expect(selected, points.last);
    expect(find.text(Money(0.3, "CNY").formattedExact), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(Money(0.3, "CNY").formattedExact), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test("chart money uses fixed two decimals without abbreviating", () {
    expect(
      Money(1234567.89123456, "CNY").formattedExact,
      Money(1234567.89123456, "CNY").formatMoney(decimalDigits: 2),
    );
    expect(Money(0, "CNY").formattedExact, endsWith("0.00"));
    expect(Money(-0.00000001, "BTC").formattedExact, endsWith("0.00"));
  });

  testWidgets("single zero point renders without inventing history", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_TestLocalizations()],
        home: Scaffold(
          body: AmountTrendChart(
            points: [AmountTrendPoint(DateTime(2026), Decimal.zero)],
            currency: "CNY",
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(Money(0, "CNY").formattedExact), findsOneWidget);
    await TransitiveLocalPreferences().sessionPrivacyMode.set(true);
    await tester.pumpAndSettle();
    expect(find.text(Money(0, "CNY").formattedExact), findsNothing);
    expect(find.text("••••"), findsOneWidget);
    await TransitiveLocalPreferences().sessionPrivacyMode.set(false);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets("month ticks and large two-decimal amounts fit a phone", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_TestLocalizations()],
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: AmountTrendChart(
              currency: "CNY",
              points: List.generate(
                20,
                (i) => AmountTrendPoint(
                  DateTime(2026, 11, i + 1),
                  Decimal.parse("123456789.123456789"),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(Money(123456789.123456789, "CNY").formattedExact),
      findsOneWidget,
    );
    expect(find.text("Nov 11"), findsOneWidget);
    expect(find.text("Nov 20"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("heatmap tap selects spending days and zero days", (
    tester,
  ) async {
    DateTime? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeFactory(flowLights.schemes.first).materialTheme,
        localizationsDelegates: const [_TestLocalizations()],
        home: Scaffold(
          body: SpendingHeatmap(
            dailyExpense: {DateTime(2026, 11, 19): 12.345},
            from: DateTime(2026, 11, 19),
            to: DateTime(2026, 11, 20),
            currency: "CNY",
            onDaySelected: (day) => selected = day,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final day in [DateTime(2026, 11, 19), DateTime(2026, 11, 20)]) {
      await tester.tap(
        find.byKey(ValueKey("spending-day-${day.toIso8601String()}")),
      );
      await tester.pumpAndSettle();
      expect(selected, day);
    }
    expect(tester.takeException(), isNull);
  });
}
