import "dart:async";

import "package:decimal/decimal.dart";
import "package:flow/data/amount_trend.dart";
import "package:flow/data/money.dart";
import "package:flow/entity/account.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/objectbox/objectbox.g.dart";
import "package:flow/services/amount_trends.dart";
import "package:flow/theme/theme.dart";
import "package:flow/utils/extensions.dart";
import "package:flow/utils/primary_currency_dependent_state.dart";
import "package:flow/widgets/general/frame.dart";
import "package:flow/widgets/general/list_header.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flow/widgets/general/spinner.dart";
import "package:flow/widgets/stats/missing_rates_notice.dart";
import "package:flow/widgets/stats/money_delta_label.dart";
import "package:flow/widgets/stats/net_worth/account_balance_share.dart";
import "package:flow/widgets/stats/net_worth/account_share_tile.dart";
import "package:flow/widgets/stats/amount_trend_chart.dart";
import "package:flow/widgets/stats/net_worth/net_worth_sample.dart";
import "package:flow/widgets/stats/stats_app_bar.dart";
import "package:flow/widgets/time_range_selector.dart";
import "package:flutter/material.dart";
import "package:moment_dart/moment_dart.dart";

/// Net worth over time.
///
/// Reconstructs month-end balances from account ledgers. The unfinished month
/// ends at now; currency conversion uses the currently available exchange rates.
///
/// Below the trend, each account's current balance is shown as a share of net
/// worth so the composition is informative no matter how many account types a
/// user has.
class NetWorthPage extends StatefulWidget {
  const NetWorthPage({super.key});

  @override
  State<NetWorthPage> createState() => _NetWorthPageState();
}

class _NetWorthPageState extends State<NetWorthPage>
    with PrimaryCurrencyDependentState<NetWorthPage> {
  TimeRange range = TimeRange.thisMonth();

  bool get monthly =>
      range.to.millisecondsSinceEpoch - range.from.millisecondsSinceEpoch >
      const Duration(days: 62).inMilliseconds;

  bool busy = false;

  /// Whether any non-primary currency balance couldn't be converted.
  bool missingRates = false;

  List<Account> accounts = [];
  List<NetWorthSample> samples = [];
  List<AccountBalanceShare> shares = [];

  /// Accounts left out of net worth via [Account.excludeFromTotalBalance].
  List<Account> excludedAccounts = [];
  List<Account> historyAccounts = [];
  Map<int, List<AmountTrendPoint>> histories = {};
  List<AmountTrendPoint> exactSamples = [];
  Decimal openingAmount = Decimal.zero;
  int? selectedAccountId;
  int generation = 0;
  StreamSubscription<Query<Account>>? accountSubscription;

  @override
  void initState() {
    super.initState();
    accountSubscription = ObjectBox().box<Account>().query().watch().listen(
      (_) => fetch(),
    );
  }

  @override
  void dispose() {
    generation++;
    accountSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasData = samples.isNotEmpty;

    final Money current = Money(
      samples.isEmpty ? 0.0 : samples.last.amount,
      primaryCurrency,
    );
    final Money first = Money(openingAmount.toDouble(), primaryCurrency);
    final Money delta = current - first;

    return Scaffold(
      appBar: StatsAppBar(title: "tabs.stats.analytics.netWorth".t(context)),
      body: SafeArea(
        child: busy && samples.isEmpty
            ? const Spinner.center()
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    const SizedBox(height: 16.0),
                    Frame(
                      child: TimeRangeSelector(
                        initialValue: range,
                        onChanged: _updateRange,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    Frame(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Text(
                            "tabs.stats.analytics.netWorth".t(context),
                            style: context.textTheme.titleSmall?.semi(context),
                          ),
                          const SizedBox(height: 2.0),
                          MoneyText(
                            current,
                            style: context.textTheme.displaySmall,
                            autoSize: true,
                            tapToToggleAbbreviation: true,
                          ),
                          const SizedBox(height: 4.0),
                          MoneyDeltaLabel(
                            delta: delta,
                            suffixLabel: "tabs.stats.analytics.inRange".t(
                              context,
                              range.format(useRelative: false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    if (hasData)
                      Frame(
                        child: AmountTrendChart(
                          points: exactSamples,
                          monthly: monthly,
                          currency: primaryCurrency,
                        ),
                      )
                    else
                      Frame(
                        child: SizedBox(
                          height: 120.0,
                          child: Center(
                            child: Text(
                              "tabs.stats.analytics.netWorth.notEnoughHistory"
                                  .t(context),
                            ),
                          ),
                        ),
                      ),
                    if (missingRates) ...[
                      const SizedBox(height: 8.0),
                      MissingRatesNotice(
                        message: "tabs.stats.analytics.missingRatesBalances".t(
                          context,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32.0),
                    if (historyAccounts.isNotEmpty) ...[
                      Frame(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "trend.monthlyAccounts".t(context),
                              style: context.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              key: ValueKey(selectedAccountId),
                              initialValue: selectedAccountId,
                              isExpanded: true,
                              items: historyAccounts
                                  .map(
                                    (account) => DropdownMenuItem(
                                      value: account.id,
                                      child: Text(
                                        "${account.name} · ${account.currency}",
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (id) =>
                                  setState(() => selectedAccountId = id),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              "trend.monthEndHint".t(context),
                              style: context.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 12),
                            AmountTrendChart(
                              key: ValueKey((selectedAccountId, range)),
                              points: histories[selectedAccountId] ?? [],
                              currency: historyAccounts
                                  .firstWhere(
                                    (account) =>
                                        account.id == selectedAccountId,
                                    orElse: () => historyAccounts.first,
                                  )
                                  .currency,
                              monthly: monthly,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    ListHeader(
                      "tabs.stats.analytics.netWorth.byAccount".t(context),
                    ),
                    const SizedBox(height: 8.0),
                    ..._buildShareRows(context),
                    if (excludedAccounts.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Frame(
                        child: Text(
                          "tabs.stats.analytics.netWorth.excluded".t(context, {
                            "accounts": excludedAccounts
                                .map((account) => account.name)
                                .join(", "),
                          }),
                          style: context.textTheme.bodySmall?.semi(context),
                        ),
                      ),
                    ],
                    const SizedBox(height: 96.0),
                  ],
                ),
              ),
      ),
    );
  }

  List<Widget> _buildShareRows(BuildContext context) {
    if (shares.isEmpty) {
      return [
        Frame(
          child: Text("tabs.stats.analytics.netWorth.noAccounts".t(context)),
        ),
      ];
    }

    // Share is relative to the gross size of holdings (sum of absolute
    // balances) so debt and assets each get a sensible bar instead of one
    // overflowing the other.
    final double gross = shares.fold<double>(
      0.0,
      (sum, share) => sum + share.amount.abs(),
    );

    return shares
        .map(
          (share) => AccountShareTile(
            share: share,
            gross: gross,
            primaryCurrency: primaryCurrency,
          ),
        )
        .toList();
  }

  void _updateRange(TimeRange value) {
    if (value == range) return;
    range = value;
    fetch();
  }

  @override
  Future<void> fetch() async {
    if (!mounted) return;
    final int request = ++generation;
    setState(() {
      busy = true;
    });

    try {
      final List<Account> allAccounts = ObjectBox().getAccounts(false);
      final List<Account> included = allAccounts
          .where((account) => account.excludeFromTotalBalance != true)
          .toList();
      final List<Account> excluded = allAccounts
          .where((account) => account.excludeFromTotalBalance == true)
          .toList();

      final DateTime historyFrom = range.from <= Moment.minValue
          ? await firstSettledLedgerDate() ?? DateTime.now()
          : range.from;
      final List<DateTime> anchors = trendAnchors(
        from: historyFrom,
        to: range.to,
        now: DateTime.now(),
        monthly: monthly,
      );
      final List<DateTime> ledgerAnchors = anchors.isEmpty
          ? []
          : [historyFrom.subtract(const Duration(microseconds: 1)), ...anchors];
      final List<List<AmountTrendPoint>> results = await Future.wait(
        allAccounts.map((account) => loadAccountTrend(account, ledgerAnchors)),
      );
      if (!mounted || request != generation) return;
      final Map<int, List<AmountTrendPoint>> nextHistories = {
        for (int i = 0; i < allAccounts.length; i++)
          allAccounts[i].id: results[i].isEmpty ? [] : results[i].sublist(1),
      };

      bool missing = false;
      Decimal nextOpening = Decimal.zero;
      for (int i = 0; i < allAccounts.length; i++) {
        final Account account = allAccounts[i];
        if (account.excludeFromTotalBalance || results[i].isEmpty) continue;
        final Decimal original = results[i].first.amount;
        if (account.currency == primaryCurrency) {
          nextOpening += original;
        } else {
          final double? converted = Money(
            original.toDouble(),
            account.currency,
          ).tryConvertAmount(primaryCurrency, rates);
          if (converted == null || !converted.isFinite) {
            missing = true;
          } else {
            nextOpening += Decimal.parse(converted.toString());
          }
        }
      }

      final List<AmountTrendPoint> nextExact = anchors.asMap().entries.map((
        entry,
      ) {
        Decimal total = Decimal.zero;
        for (final Account account in included) {
          final Decimal original = nextHistories[account.id]![entry.key].amount;
          final double? value = Money(
            original.toDouble(),
            account.currency,
          ).tryConvertAmount(primaryCurrency, rates);
          if (account.currency == primaryCurrency) {
            total += original;
          } else if (value != null && value.isFinite) {
            total += Decimal.parse(value.toString());
          }
          missing = missing || value == null;
        }
        return AmountTrendPoint(entry.value, total);
      }).toList();

      final List<AccountBalanceShare> nextShares = [];
      for (final Account account in included) {
        final double? value = account.balance.tryConvertAmount(
          primaryCurrency,
          rates,
        );
        missing = missing || value == null;

        if ((value ?? 0.0) == 0.0) continue;
        nextShares.add(AccountBalanceShare(account, value!));
      }
      nextShares.sort((a, b) => b.amount.abs().compareTo(a.amount.abs()));

      accounts = included;
      excludedAccounts = excluded;
      historyAccounts = allAccounts;
      histories = nextHistories;
      if (!allAccounts.any((account) => account.id == selectedAccountId)) {
        selectedAccountId = allAccounts.firstOrNull?.id;
      }
      exactSamples = nextExact;
      openingAmount = nextOpening;
      samples = nextExact
          .map((point) => NetWorthSample(point.date, point.amount.toDouble()))
          .toList();
      shares = nextShares;
      missingRates = missing;
    } finally {
      if (mounted && request == generation) {
        busy = false;
        setState(() {});
      }
    }
  }
}
