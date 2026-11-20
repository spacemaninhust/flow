import "package:flow/data/money.dart";
import "package:flow/data/amount_trend.dart";
import "package:flow/entity/account.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/theme/theme.dart";
import "package:flow/utils/extensions.dart";
import "package:flow/utils/primary_currency_dependent_state.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flow/widgets/home/stats/bento/bento_tile.dart";
import "package:flow/widgets/home/stats/bento/net_worth_sparkline.dart";
import "package:flow/widgets/stats/money_delta_label.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:material_symbols_icons_flow/symbols.dart";
import "package:moment_dart/moment_dart.dart";

/// Bento preview of net worth: the current total, its change over the sampled
/// window, and a minimal sparkline for the current month.
class NetWorthTile extends StatefulWidget {
  const NetWorthTile({super.key});

  @override
  State<NetWorthTile> createState() => _NetWorthTileState();
}

class _NetWorthTileState extends State<NetWorthTile>
    with PrimaryCurrencyDependentState<NetWorthTile> {
  bool busy = true;
  bool loaded = false;

  List<double> samples = [];
  List<DateTime> sampleAnchors = [];

  @override
  Widget build(BuildContext context) {
    final bool hasTrend = samples.length >= 2;
    final double currentAmount = samples.isEmpty ? 0.0 : samples.last;
    final double firstAmount = samples.isEmpty ? 0.0 : samples.first;

    return BentoTile(
      label: "tabs.stats.analytics.netWorth".t(context),
      icon: Symbols.trending_up_rounded,
      height: 188.0,
      busy: busy && !loaded,
      onTap: () => context.push("/stats/net-worth"),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          MoneyText(
            Money(currentAmount, primaryCurrency),
            style: context.textTheme.headlineMedium,
            autoSize: true,
            initiallyAbbreviated: true,
          ),
          const SizedBox(height: 4.0),
          MoneyDeltaLabel(
            delta: Money(currentAmount - firstAmount, primaryCurrency),
            suffixLabel: "tabs.stats.analytics.inRange".t(
              context,
              TimeRange.thisMonth().format(),
            ),
            iconSize: 16.0,
            initiallyAbbreviated: true,
            suffixStyle: context.textTheme.bodySmall?.semi(context),
          ),
          const SizedBox(height: 12.0),
          Expanded(
            child: hasTrend
                ? NetWorthSparkline(
                    samples: samples,
                    color: context.colorScheme.primary,
                    anchors: sampleAnchors,
                    currency: primaryCurrency,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> fetch() async {
    try {
      final List<Account> accounts = ObjectBox()
          .getAccounts(false)
          .where((account) => account.excludeFromTotalBalance != true)
          .toList();

      final DateTime now = DateTime.now();
      final List<DateTime> anchors = trendAnchors(
        from: DateTime(now.year, now.month),
        to: now,
        now: now,
        monthly: false,
      );
      sampleAnchors = anchors;

      samples = anchors.map((anchor) {
        double total = 0.0;
        for (final Account account in accounts) {
          total +=
              account
                  .balanceAt(anchor)
                  .tryConvertAmount(primaryCurrency, rates) ??
              0.0;
        }
        return total;
      }).toList();
      loaded = true;
    } finally {
      busy = false;
      if (mounted) setState(() {});
    }
  }
}
