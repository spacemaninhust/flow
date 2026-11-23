import "package:decimal/decimal.dart";
import "package:flow/data/amount_trend.dart";
import "package:flow/data/money.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/theme/theme.dart";
import "package:flow/utils/extensions.dart";
import "package:flow/utils/primary_currency_dependent_state.dart";
import "package:flow/widgets/analytics/spending_heatmap.dart";
import "package:flow/widgets/analytics/weekday_bars.dart";
import "package:flow/widgets/general/spinner.dart";
import "package:flow/widgets/stats/emphasized_text.dart";
import "package:flow/widgets/stats/missing_rates_notice.dart";
import "package:flow/widgets/stats/stats_app_bar.dart";
import "package:flow/widgets/stats/stats_empty_state.dart";
import "package:flow/widgets/time_range_selector.dart";
import "package:flow/widgets/stats/amount_trend_chart.dart";
import "package:flow/widgets/stats/exact_amount_text.dart";
import "package:flow/widgets/stats/calendar/calendar_overview.dart";
import "package:flow/widgets/stats/calendar/calendar_section.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:material_symbols_icons_flow/symbols.dart";
import "package:moment_dart/moment_dart.dart";

/// Spending calendar — a heatmap of daily spend intensity.
///
/// Bins expenses by [Transaction.transactionDate] and renders a GitHub-style
/// grid, plus a weekday breakdown. The weekday rhythm is computed here because
/// `TrendsReport.expenseByWeekday` is never populated upstream.
class SpendingCalendarPage extends StatefulWidget {
  const SpendingCalendarPage({super.key});

  @override
  State<SpendingCalendarPage> createState() => _SpendingCalendarPageState();
}

class _SpendingCalendarPageState extends State<SpendingCalendarPage>
    with PrimaryCurrencyDependentState<SpendingCalendarPage> {
  TimeRange range = TimeRange.thisMonth();

  bool busy = false;
  bool missingRates = false;

  Map<DateTime, double> dailyExpense = {};
  Map<int, double> weekdayExpense = {};
  double total = 0.0;
  DateTime from = DateTime.now();
  DateTime to = DateTime.now();
  List<AmountTrendPoint> points = [];
  List<Transaction> expenses = [];
  DateTime? selectedDay;
  int generation = 0;

  @override
  Widget build(BuildContext context) {
    final bool hasData = dailyExpense.isNotEmpty;

    return Scaffold(
      appBar: StatsAppBar(
        title: "tabs.stats.analytics.spendingCalendar".t(context),
      ),
      body: SafeArea(
        child: busy && dailyExpense.isEmpty
            ? const Spinner.center()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    TimeRangeSelector(
                      initialValue: range,
                      onChanged: _updateRange,
                    ),
                    const SizedBox(height: 20),
                    CalendarOverview(
                      total: Money(total, primaryCurrency),
                      days: points.length,
                      label: "tabs.stats.analytics.calendar.spentIn".t(
                        context,
                        range.format(useRelative: false),
                      ),
                    ),
                    const SizedBox(height: 24),
                    CalendarSection(
                      icon: Symbols.show_chart_rounded,
                      title: "calendar.dailyTrend".t(context),
                      subtitle: "calendar.trendSubtitle".t(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AmountTrendChart(
                            points: points,
                            currency: primaryCurrency,
                            height: 180,
                            onSelected: (point) =>
                                setState(() => selectedDay = point.date),
                          ),
                          if (points.isNotEmpty) ...[
                            Divider(
                              height: 32,
                              color: context.colorScheme.onSurface.withAlpha(
                                24,
                              ),
                            ),
                            _dayDetails(context, compact: true),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (hasData)
                      CalendarSection(
                        icon: Symbols.calendar_month_rounded,
                        title: "calendar.distribution".t(context),
                        subtitle: "calendar.heatmapSubtitle".t(context),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SpendingHeatmap(
                              dailyExpense: dailyExpense,
                              from: from,
                              to: to,
                              currency: primaryCurrency,
                              onDaySelected: _showHeatmapDay,
                              cellSize: 24,
                              gap: 6,
                            ),
                            if (weekdayExpense.isNotEmpty) ...[
                              Divider(
                                height: 40,
                                color: context.colorScheme.onSurface.withAlpha(
                                  24,
                                ),
                              ),
                              _buildWeekdayInsight(context),
                            ],
                          ],
                        ),
                      )
                    else
                      StatsEmptyState(
                        message: "tabs.stats.analytics.noSpendingWindow".t(
                          context,
                        ),
                      ),
                    if (missingRates) ...[
                      const SizedBox(height: 8.0),
                      MissingRatesNotice(
                        message: "tabs.stats.analytics.missingRatesAmounts".t(
                          context,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  void _showHeatmapDay(DateTime day) {
    setState(() => selectedDay = day);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .65,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: _dayDetails(context, date: day),
          ),
        ),
      ),
    );
  }

  Widget _dayDetails(
    BuildContext context, {
    DateTime? date,
    bool compact = false,
  }) {
    final DateTime day = date ?? selectedDay ?? points.last.date;
    final List<Transaction> items = expenses
        .where(
          (transaction) =>
              transaction.transactionDate.year == day.year &&
              transaction.transactionDate.month == day.month &&
              transaction.transactionDate.day == day.day,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          ExactAmountText(
            amount: points
                .where((point) => DateUtils.isSameDay(point.date, day))
                .first
                .amount,
            currency: primaryCurrency,
            style: context.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                "trend.dayDetails".t(
                  context,
                  day.toMoment().format("YYYY-MM-DD"),
                ),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (compact)
              IconButton(
                tooltip: "calendar.viewDay".t(context),
                onPressed: () => _showHeatmapDay(day),
                icon: const Icon(Symbols.open_in_new_rounded, size: 18),
              ),
          ],
        ),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              "trend.noSpending".t(context),
              style: context.textTheme.bodySmall,
            ),
          ),
        ...(compact ? items.take(2) : items).map(
          (transaction) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              transaction.title?.isNotEmpty == true
                  ? transaction.title!
                  : "trend.expense".t(context),
            ),
            subtitle: Text(
              transaction.transactionDate.toMoment().format("HH:mm"),
            ),
            trailing: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * .35,
              ),
              child: ExactAmountText(
                amount: Decimal.parse(transaction.amount.abs().toString()),
                currency: transaction.currency,
                selectable: false,
              ),
            ),
            onTap: () => context.push("/transaction/${transaction.id}"),
          ),
        ),
        if (compact && items.length > 2)
          TextButton(
            onPressed: () => _showHeatmapDay(day),
            child: Text("calendar.viewTransactions".t(context, items.length)),
          ),
      ],
    );
  }

  Widget _buildWeekdayInsight(BuildContext context) {
    final int topWeekday = weekdayExpense.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "tabs.stats.analytics.rhythm".t(context),
          style: context.textTheme.labelLarge?.copyWith(
            color: context.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        EmphasizedText(
          template: "tabs.stats.analytics.calendar.priciestDay".t(context),
          value: _weekdayName(topWeekday),
        ),
        const SizedBox(height: 16),
        WeekdayBars(
          byWeekday: weekdayExpense,
          topWeekday: topWeekday,
          accent: context.colorScheme.primary,
          weekdayLabels: List.generate(
            7,
            (index) => DateTime(2024, 1, index + 1).toMoment().format("dd"),
          ),
        ),
      ],
    );
  }

  void _updateRange(TimeRange value) {
    if (value == range) return;
    range = value;
    selectedDay = null;
    fetch();
  }

  @override
  Future<void> fetch() async {
    if (!mounted) return;
    final int request = ++generation;
    setState(() {
      busy = true;
    });

    bool missing = false;

    try {
      // Heatmap cells past today render empty, so cap the grid at "now" when
      // the range runs into the future (e.g. the remainder of this year).
      final DateTime now = DateTime.now();
      from = range.from;
      to = range.to.isAfter(now) ? now : range.to;

      final List<Transaction> transactions = await ObjectBox()
          .transcationsByRange(range, includeTransfers: false);

      final Map<DateTime, double> daily = {};
      final Map<DateTime, Decimal> exactDaily = {};
      final List<Transaction> included = [];
      final Map<int, double> weekday = {};
      double sum = 0.0;

      for (final Transaction transaction in transactions) {
        if (transaction.type != TransactionType.expense) continue;
        if (transaction.transactionSubtype ==
                TransactionSubtype.updateBalance ||
            transaction.transactionDate.isAfter(now)) {
          continue;
        }

        final double? converted = transaction.money.tryConvertAmount(
          primaryCurrency,
          rates,
        );
        if (converted == null || !converted.isFinite) {
          missing = true;
          continue;
        }

        final double magnitude = converted.abs();
        final DateTime day = DateTime(
          transaction.transactionDate.year,
          transaction.transactionDate.month,
          transaction.transactionDate.day,
        );

        daily[day] = (daily[day] ?? 0.0) + magnitude;
        exactDaily[day] =
            (exactDaily[day] ?? Decimal.zero) +
            Decimal.parse(magnitude.toString());
        included.add(transaction);
        weekday[transaction.transactionDate.weekday] =
            (weekday[transaction.transactionDate.weekday] ?? 0.0) + magnitude;
        sum += magnitude;
      }

      if (!mounted || request != generation) return;
      if (range.from <= Moment.minValue) {
        from = included.isEmpty
            ? now
            : included
                  .map((transaction) => transaction.transactionDate)
                  .reduce((a, b) => a.isBefore(b) ? a : b);
      }
      points = dailySpendingTrend(
        exactDaily,
        trendAnchors(from: from, to: range.to, now: now, monthly: false),
      );
      expenses = included;
      dailyExpense = daily;
      weekdayExpense = weekday;
      total = sum;
      missingRates = missing;
    } finally {
      if (mounted && request == generation) {
        busy = false;
        setState(() {});
      }
    }
  }

  String _weekdayName(int weekday) {
    // 1 == Monday .. 7 == Sunday (DateTime.weekday).
    return DateTime(2024, 1, weekday).toMoment().format("dddd");
  }
}
