import "dart:io";

import "package:flow/data/flow_icon.dart";
import "package:flow/data/money.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/budget.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/l10n/flow_localizations.dart";
import "package:flow/objectbox.dart";
import "package:flow/prefs/local_preferences.dart";
import "package:flow/providers/accounts_provider.dart";
import "package:flow/routes/account_page.dart";
import "package:flow/routes/budget_page.dart";
import "package:flow/routes/budget_detail_page.dart";
import "package:flow/widgets/budgets/budget_category_usage.dart";
import "package:flow/widgets/home/stats/bento/top_categories_tile.dart";
import "package:flow/routes/stats/net_worth_page.dart";
import "package:flow/routes/stats/spending_calendar_page.dart";
import "package:flow/services/user_preferences.dart";
import "package:flow/theme/color_themes/registry.dart";
import "package:flow/theme/theme.dart";
import "package:flow/widgets/stats/amount_trend_chart.dart";
import "package:flow/widgets/time_range_selector.dart";
import "package:flutter/material.dart";
import "package:flutter/foundation.dart" hide Category;
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
import "package:go_router/go_router.dart";

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
  late Category eatingOut;
  late Budget budget;
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
    eatingOut = Category(
      name: "外食",
      iconCode: const IconFlowIcon(Symbols.restaurant_rounded).toString(),
    );
    ObjectBox().box<Category>().put(eatingOut);
    ObjectBox().box<Category>().put(
      Category(
        name: "无花销类别",
        iconCode: const IconFlowIcon(Symbols.shopping_bag_rounded).toString(),
      ),
    );
    budget = Budget(
      name: "月度预算",
      amount: 10000,
      currency: "CNY",
      range: TimeRange.thisMonth().toString(),
    )..categoryLimits = {eatingOut.uuid: 20};
    ObjectBox().box<Budget>().put(budget);
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
      if (amount < 0 && subtype == null) transaction.setCategory(eatingOut);
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

  Future<void> show(
    WidgetTester tester,
    Widget page, {
    double width = 430,
    bool dark = false,
  }) async {
    tester.view.physicalSize = Size(width, 1100);
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
    final theme = ThemeFactory(
      dark ? flowDarks.schemes.first : flowLights.schemes.first,
    ).materialTheme;
    final router = GoRouter(
      initialLocation: "/preview",
      routes: [
        GoRoute(
          path: "/",
          builder: (_, _) => const SizedBox.shrink(),
          routes: [
            GoRoute(
              path: "preview",
              builder: (_, _) => AccountsProvider([cash, savings], child: page),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
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
        routerConfig: router,
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
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/calendar-distribution.png"),
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

  testWidgets("calendar narrow dark layout preview", (tester) async {
    await show(tester, const SpendingCalendarPage(), width: 360, dark: true);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/calendar-dark.png"),
    );
    expect(tester.takeException(), isNull);
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

  testWidgets("budget category editor and usage preview", (tester) async {
    await show(tester, BudgetPage(budgetId: budget.id));
    final field = find.byKey(ValueKey("category-limit-${eatingOut.uuid}"));
    await tester.ensureVisible(field);
    await tester.enterText(field, "101");
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.pumpAndSettle();
    expect(find.text("请输入 0 到 100 之间的比例"), findsOneWidget);
    await tester.enterText(field, "20");
    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/budget-editor.png"),
    );
    await tester.enterText(field, "30");
    await tester.tap(find.byTooltip("保存"));
    await settle(tester);
    expect(
      ObjectBox().box<Budget>().get(budget.id)!.categoryLimits[eatingOut.uuid],
      30,
    );
    final now = DateTime.now();
    final txn = Transaction(
      uuid: const Uuid().v4(),
      currency: "CNY",
      amount: -2500,
      transactionDate: now,
    )..setCategory(eatingOut);
    await show(
      tester,
      Scaffold(
        body: BudgetCategoryUsage(budget: budget, transactions: [txn]),
      ),
    );
    expect(find.text("已用：25.00%"), findsOneWidget);
    expect(find.text("上限：20.00%"), findsOneWidget);
    expect(find.text("已超出"), findsOneWidget);
    expect(find.text(Money(500, "CNY").formattedExact), findsOneWidget);
    expect(find.text("无花销类别"), findsNothing);
    expect(find.text(Money(2000, "CNY").formatted), findsOneWidget);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/budget-usage.png"),
    );
    await show(tester, BudgetDetailPage(budgetId: budget.id));
    await tester.ensureVisible(find.text("各类别预算占用"));
    await tester.pumpAndSettle();
    expect(find.text("上限：30.00%"), findsOneWidget);
    expect(tester.takeException(), isNull);
    await show(tester, BudgetPage(budgetId: budget.id));
    final mode = find.byKey(ValueKey("category-limit-mode-${eatingOut.uuid}"));
    await tester.ensureVisible(mode);
    await tester.tap(mode);
    await tester.pumpAndSettle();
    await tester.tap(find.text("固定金额").last);
    await tester.pumpAndSettle();
    final amountField = find.byKey(
      ValueKey("category-amount-limit-${eatingOut.uuid}"),
    );
    expect(tester.widget<TextFormField>(amountField).initialValue, "3000.0");
    await tester.ensureVisible(amountField);
    await tester.enterText(amountField, "-1");
    expect(tester.state<FormState>(find.byType(Form)).validate(), isFalse);
    await tester.enterText(amountField, "2000");
    expect(tester.state<FormState>(find.byType(Form)).validate(), isTrue);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/budget-editor-fixed.png"),
    );
    await tester.tap(find.byTooltip("保存"));
    await settle(tester);
    final fixedBudget = ObjectBox().box<Budget>().get(budget.id)!;
    expect(fixedBudget.categoryLimits, isEmpty);
    expect(fixedBudget.categoryAmountLimits[eatingOut.uuid], 2000);
    await show(tester, BudgetDetailPage(budgetId: budget.id));
    await tester.ensureVisible(find.text("各类别预算占用"));
    await tester.pumpAndSettle();
    expect(find.text("固定金额上限"), findsOneWidget);
    expect(find.text("无花销类别"), findsNothing);
    await show(
      tester,
      Scaffold(
        body: BudgetCategoryUsage(budget: fixedBudget, transactions: []),
      ),
    );
    expect(find.text("各类别预算占用"), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !renderPreview);

  testWidgets("popular categories show totals and daily averages", (
    tester,
  ) async {
    await show(
      tester,
      Scaffold(body: TopCategoriesTile(range: TimeRange.thisMonth())),
    );
    expect(find.text("外食"), findsOneWidget);
    expect(find.text("平均每天花销"), findsOneWidget);
    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile("../../docs/previews/top-categories.png"),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  }, skip: !renderPreview);

  testWidgets("category remaining and over-limit cards light and dark", (
    tester,
  ) async {
    final transport = Category(
      name: "交通",
      iconCode: const IconFlowIcon(Symbols.train_rounded).toString(),
    );
    ObjectBox().box<Category>().put(transport);
    final sampleBudget =
        Budget(
            name: "对比预算",
            amount: 10000,
            currency: "CNY",
            range: TimeRange.thisMonth().toString(),
          )
          ..categoryLimits = {eatingOut.uuid: 20}
          ..categoryAmountLimits = {transport.uuid: 800};
    final txns = [
      Transaction(
        uuid: const Uuid().v4(),
        currency: "CNY",
        amount: -2500,
        transactionDate: DateTime.now(),
      )..setCategory(eatingOut),
      Transaction(
        uuid: const Uuid().v4(),
        currency: "CNY",
        amount: -300,
        transactionDate: DateTime.now(),
      )..setCategory(transport),
    ];
    for (final dark in [false, true]) {
      await show(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: BudgetCategoryUsage(
              budget: sampleBudget,
              transactions: txns,
            ),
          ),
        ),
        width: dark ? 360 : 430,
        dark: dark,
      );
      expect(find.text("已超出"), findsOneWidget);
      expect(find.text("还可花"), findsOneWidget);
      expect(find.text(Money(500, "CNY").formattedExact), findsNWidgets(2));
      final remaining = tester.widget<Text>(find.text("还可花"));
      final over = tester.widget<Text>(find.text("已超出"));
      expect(remaining.style!.color!.g, greaterThan(remaining.style!.color!.r));
      expect(over.style!.color!.r, greaterThan(over.style!.color!.g));
      await expectLater(
        find.byType(Scaffold).first,
        matchesGoldenFile(
          "../../docs/previews/budget-room-${dark ? 'dark' : 'light'}.png",
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  }, skip: !renderPreview);
}
