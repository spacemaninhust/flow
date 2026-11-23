import "package:flow/l10n/extensions.dart";
import "package:flow/data/spending_statistics.dart";
import "package:flow/services/amount_trends.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/theme/theme.dart";
import "package:flow/utils/primary_currency_dependent_state.dart";
import "package:flow/widgets/home/stats/bento/bento_tile.dart";
import "package:flow/widgets/home/stats/bento/category_slice_row.dart";
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:material_symbols_icons_flow/symbols.dart";
import "package:moment_dart/moment_dart.dart";

/// One category's spend share for the bento preview.
class _Slice {
  final String name;
  final double amount;
  final Color color;

  const _Slice({required this.name, required this.amount, required this.color});
}

/// Bento preview of the top spending categories for the selected range.
class TopCategoriesTile extends StatefulWidget {
  final TimeRange range;

  const TopCategoriesTile({super.key, required this.range});

  @override
  State<TopCategoriesTile> createState() => _TopCategoriesTileState();
}

class _TopCategoriesTileState extends State<TopCategoriesTile>
    with PrimaryCurrencyDependentState<TopCategoriesTile> {
  static const int _maxRows = 3;

  bool busy = true;
  bool loaded = false;

  List<_Slice> slices = [];
  double maxAmount = 0.0;
  int averageDays = 0;
  int generation = 0;

  @override
  void didUpdateWidget(TopCategoriesTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.range != oldWidget.range) fetch();
  }

  @override
  Widget build(BuildContext context) {
    return BentoTile(
      label: "tabs.stats.analytics.topCategories".t(context),
      icon: Symbols.donut_small_rounded,
      height: 80 + (slices.isEmpty ? 1 : slices.length) * 60.0,
      busy: busy && !loaded,
      onTap: () => context.push(
        "/stats/category?range=${Uri.encodeQueryComponent(widget.range.encodeShort())}",
      ),
      child: slices.isEmpty
          ? Text(
              "tabs.stats.analytics.noSpendingRange".t(context),
              style: context.textTheme.bodySmall?.semi(context),
            )
          : Column(
              crossAxisAlignment: .start,
              mainAxisAlignment: .spaceEvenly,
              children: slices
                  .map(
                    (slice) => CategorySliceRow(
                      name: slice.name,
                      amount: slice.amount,
                      color: slice.color,
                      maxAmount: maxAmount,
                      currency: primaryCurrency,
                      averageDays: averageDays,
                    ),
                  )
                  .toList(),
            ),
    );
  }

  @override
  Future<void> fetch() async {
    final request = ++generation;
    final range = widget.range;
    try {
      final now = DateTime.now();
      final from = range.from <= Moment.minValue
          ? await firstSettledLedgerDate() ?? now
          : range.from;
      if (!mounted || request != generation) return;
      final days = elapsedSpendingDays(from, range.to, now);
      if (days == 0) {
        slices = [];
        averageDays = 0;
        loaded = true;
        return;
      }
      final end = range.to.isBefore(now) ? range.to : now;
      final analytics = await ObjectBox().flowByCategories(
        range: CustomTimeRange(from, end.isBefore(from) ? from : end),
      );

      // Resolve the theme palette only after the await — the first fetch runs
      // from initState (via the mixin), before inherited widgets are readable.
      if (!mounted || request != generation) return;
      averageDays = days;
      final List<Color> palette = context.chartAccents;

      final List<_Slice> next = [];
      int colorIndex = 0;

      for (final entry in analytics.flow.entries) {
        final flow = entry.value;
        final double expense = flow
            .merge(primaryCurrency, rates)
            .totalExpense
            .amount
            .abs();
        if (expense <= 0) continue;

        final String name =
            flow.associatedData?.name ??
            "tabs.stats.analytics.uncategorized".tr();
        final Color color =
            flow.associatedData?.colorScheme?.primary ??
            palette[colorIndex++ % palette.length];

        next.add(_Slice(name: name, amount: expense, color: color));
      }

      next.sort((a, b) => b.amount.compareTo(a.amount));

      slices = next.take(_maxRows).toList();
      maxAmount = slices.isEmpty ? 0.0 : slices.first.amount;
      loaded = true;
    } finally {
      if (mounted && request == generation) setState(() => busy = false);
    }
  }
}
