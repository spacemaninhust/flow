import "dart:io";

import "package:flow/data/flow_icon.dart";
import "package:flow/data/money.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/l10n/flow_localizations.dart";
import "package:flow/objectbox.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/providers/accounts_provider.dart";
import "package:flow/routes/account_page.dart";
import "package:flow/routes/stats/net_worth_page.dart";
import "package:flow/routes/stats/spending_calendar_page.dart";
import "package:flow/services/user_preferences.dart";
import "package:flow/theme/color_themes/registry.dart";
import "package:flow/theme/theme.dart";
import "package:flow/widgets/stats/amount_trend_chart.dart";
import "package:flow/widgets/time_range_selector.dart";
import "package:flutter/material.dart";
import "package:flutter/foundation.dart";
import "package:flutter/services.dart";
import "package:flutter_localizations/flutter_localizations.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_symbols_icons_flow/symbols.dart";
import "package:moment_dart/moment_dart.dart";
import "package:shared_preferences/shared_preferences.dart";
// The in-memory implementation is test infrastructure for the existing plugin.
// ignore: depend_on_referenced_packages
import "package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart";
// ignore: depend_on_referenced_packages
import "package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart";
import "package:uuid/uuid.dart";

class _PreviewLocalizations extends LocalizationsDelegate<FlowLocalizations> {
  const _PreviewLocalizations();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<FlowLocalizations> load(Locale locale) =>
      SynchronousFuture(FlowLocalizations(const Locale("zh", "CN")));
  @override
  bool shouldReload(covariant _PreviewLocalizations old) => false;
}

/// Real routes, an isolated ObjectBox ledger, and deterministic demo amounts.
/// Re-render with --update-goldens; this never opens a user's app database.
void main() {
  const bool renderPreview = bool.fromEnvironment("FLOW_PREVIEW");
  TestWidgetsFlutterBinding.ensureInitialized();
  late Account cash;
  late Account savings;
  late Directory temporary;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await LocalPreferences.initialize();
    await FlowLocalizations(const Locale("zh", "CN")).load();
    UserPreferencesService().value.primaryCurrency = "CNY";
    Moment.setGlobalLocalization(MomentLocalizations.zhCn());
    temporary = await Directory.systemTemp.createTemp("flow-trend-preview-");
    await ObjectBox.initialize(
      customDirectory: temporary.path,
      subdirectory: "demo",
    );
    cash = Account(
      name: "日常账户",
      currency: "CNY",
      iconCode: const IconFlowIcon(Symbols.wallet_rounded).toString(),
    );
    savings = Account(
      name: "储蓄账户",
      currency: "CNY",
      iconCode: const IconFlowIcon(Symbols.savings_rounded).toString(),
    );
    ObjectBox().box<Account>().putMany([cash, savings]);
    final now = DateTime.now();
    void add(
      Account account,
      DateTime date,
      double amount,
      String title, {
      String? subtype,
    }) {
      final transaction = Transaction(
        uuid: const Uuid().v4(),
        currency: "CNY",
        amount: amount,
        title: title,
        transactionDate: date,
        subtype: subtype,
      );
      transaction.setAccount(account);
      ObjectBox().box<Transaction>().put(transaction);
    }

    add(
      cash,
      DateTime(now.year - 1, 12, 31),
      10000.123456,
      "期初余额",
      subtype: TransactionSubtype.updateBalance.value,
    );
    add(
      savings,
      DateTime(now.year - 1, 12, 31),
      30000.8,
      "期初余额",
      subtype: TransactionSubtype.updateBalance.value,
    );
    for (int month = 1; month <= now.month; month++) {
      add(cash, DateTime(now.year, month, 1), 8000.25, "工资");
      add(savings, DateTime(now.year, month, 1), 1500.12, "储蓄");
      final int lastDay = month == now.month ? now.day : 28;
      for (int day = 1; day <= lastDay; day++) {
        final double expense = day == now.day && month == now.month
            ? 1234.5678
            : (day % 7 + 1) * 18.23;
        add(
          cash,
          DateTime(now.year, month, day),
          -expense,
          day == now.day ? "生活购物" : "日常消费",
        );
      }
    }
  });

  tearDownAll(() async {
    ObjectBox().store.close();
    await temporary.delete(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (int i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Future<void> show(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(() async {
      final font = FontLoader("PreviewChinese")
        ..addFont(
          File(
            "C:/Windows/Fonts/NotoSansSC-VF.ttf",
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await font.load();
      final material = FontLoader("MaterialIcons")
        ..addFont(rootBundle.load("fonts/MaterialIcons-Regular.otf"));
      await material.load();
      for (final family in [
        "MaterialSymbolsRounded",
        "MaterialSymbolsOutlined",
      ]) {
        final loader =
            FontLoader("packages/material_symbols_icons_flow/$family")..addFont(
              rootBundle.load(
                "packages/material_symbols_icons_flow/lib/fonts/$family.ttf",
              ),
            );
        await loader.load();
      }
    });
    final theme = ThemeFactory(flowLights.schemes.first).materialTheme;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale("zh", "CN"),
        supportedLocales: const [Locale("zh", "CN")],
        localizationsDelegates: const [
          _PreviewLocalizations(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: "PreviewChinese"),
        ),
        home: AccountsProvider([cash, savings], child: page),
      ),
    );
    await settle(tester);
  }

  testWidgets("calendar real page preview", (tester) async {
    await show(tester, const SpendingCalendarPage());
    expect(find.text(Money(1234.5678, "CNY").formattedExact), findsWidgets);
    expect(
      tester
          .widget<TimeRangeSelector>(find.byType(TimeRangeSelector))
          .initialValue,
      TimeRange.thisMonth(),
    );
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/calendar.png"),
    );
    await tester.tap(find.byTooltip("上一个数据点"));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month, now.day - 1);
    expect(
      find.text("${previous.toMoment().format('YYYY-MM-DD')} 的支出明细"),
      findsOneWidget,
    );
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/calendar-selected.png"),
    );
    final day = DateTime(now.year, now.month, now.day);
    await tester.ensureVisible(
      find.byKey(ValueKey("spending-day-${day.toIso8601String()}")),
    );
    await tester.tap(
      find.byKey(ValueKey("spending-day-${day.toIso8601String()}")),
    );
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(Money(1234.5678, "CNY").formattedExact),
      ),
      findsWidgets,
    );
    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();
    tester
        .widget<TimeRangeSelector>(find.byType(TimeRangeSelector))
        .onChanged(Moment.minValue.rangeToMax());
    await settle(tester);
    expect(
      tester
          .widget<AmountTrendChart>(find.byType(AmountTrendChart))
          .points
          .length,
      lessThanOrEqualTo(366),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !renderPreview);

  testWidgets("net worth and account selector real page preview", (
    tester,
  ) async {
    await show(tester, const NetWorthPage());
    expect(
      tester
          .widget<TimeRangeSelector>(find.byType(TimeRangeSelector))
          .initialValue,
      TimeRange.thisMonth(),
    );
    final netWorthChart = tester
        .widgetList<AmountTrendChart>(find.byType(AmountTrendChart))
        .first;
    expect(netWorthChart.monthly, isFalse);
    expect(netWorthChart.points.length, DateTime.now().day);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/net-worth-overview.png"),
    );
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/net-worth.png"),
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text("储蓄账户 · CNY").last);
    await tester.pumpAndSettle();
    expect(find.text(Money(46502.12, "CNY").formattedExact), findsWidgets);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/net-worth-savings.png"),
    );
    tester
        .widget<TimeRangeSelector>(find.byType(TimeRangeSelector))
        .onChanged(Moment.minValue.rangeToMax());
    await settle(tester);
    for (final chart in tester.widgetList<AmountTrendChart>(
      find.byType(AmountTrendChart),
    )) {
      expect(chart.points.length, lessThanOrEqualTo(24));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !renderPreview);

  testWidgets("account real page preview", (tester) async {
    await show(tester, AccountPage(accountId: cash.id));
    expect(
      tester
          .widget<TimeRangeSelector>(find.byType(TimeRangeSelector))
          .initialValue,
      TimeRange.thisMonth(),
    );
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/account.png"),
    );
    tester
        .widget<TimeRangeSelector>(find.byType(TimeRangeSelector))
        .onChanged(Moment.minValue.rangeToMax());
    await settle(tester);
    expect(
      tester
          .widget<AmountTrendChart>(find.byType(AmountTrendChart))
          .points
          .length,
      lessThanOrEqualTo(24),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !renderPreview);
}
