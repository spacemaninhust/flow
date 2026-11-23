import "package:decimal/decimal.dart";
import "package:flow/data/budget_category_room.dart";
import "package:flow/data/exchange_rates.dart";
import "package:flow/entity/budget.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/services/budget.dart";
import "package:flow/theme/theme.dart";
import "package:flow/widgets/general/flow_icon.dart";
import "package:flow/widgets/stats/exact_amount_text.dart";
import "package:flutter/material.dart";
import "package:material_symbols_icons_flow/symbols.dart";

/// Calendar-style cards explain each spending category's use and monetary room.
class BudgetCategoryUsage extends StatelessWidget {
  final Budget budget;
  final List<Transaction> transactions;
  final ExchangeRates? rates;

  const BudgetCategoryUsage({
    super.key,
    required this.budget,
    required this.transactions,
    this.rates,
  });

  @override
  Widget build(BuildContext context) {
    final categories = budget.categories.isEmpty
        ? ObjectBox().getCategories()
        : budget.categories.toList();
    final rows = <({Category? category, double amount, bool missing})>[];
    for (final category in <Category?>[...categories, null]) {
      final items = transactions.where((t) => t.categoryUuid == category?.uuid);
      final flow = BudgetService().computeSpent(budget, items, rates);
      final amount = flow.totalExpense.amount.abs();
      if (amount == 0 && !flow.hasMissingData) continue;
      rows.add((
        category: category,
        amount: amount,
        missing: flow.hasMissingData,
      ));
    }
    rows.sort((a, b) => b.amount.compareTo(a.amount));
    if (rows.isEmpty) return const SizedBox.shrink();
    final limits = budget.categoryLimits;
    final fixedLimits = budget.categoryAmountLimits;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "budget.categoryUsage".t(context),
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "budget.categoryRoomHint".t(context),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface.withAlpha(170),
            ),
          ),
          const SizedBox(height: 16),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryRoomCard(
                category: row.category,
                amount: row.amount,
                budget: budget,
                percentage: limits[row.category?.uuid],
                fixedAmount: fixedLimits[row.category?.uuid],
                missingRates: row.missing,
              ),
            ),
          Text(
            "budget.categoryUsageHint".t(context),
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRoomCard extends StatelessWidget {
  final Category? category;
  final Budget budget;
  final double amount;
  final double? percentage;
  final double? fixedAmount;
  final bool missingRates;

  const _CategoryRoomCard({
    required this.category,
    required this.budget,
    required this.amount,
    required this.percentage,
    required this.fixedAmount,
    required this.missingRates,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final room = BudgetCategoryRoom(
      spent: amount,
      budgetAmount: budget.amount,
      percentage: percentage,
      fixedAmount: fixedAmount,
    );
    final hasRoom = room.remaining != null && !missingRates;
    final statusColor = !hasRoom
        ? colors.primary
        : room.exceeded
        ? (dark ? const Color(0xFFFF8A80) : const Color(0xFFB91C1C))
        : (dark ? const Color(0xFF86EFAC) : const Color(0xFF15803D));
    final usedRatio = budget.amount > 0 ? amount / budget.amount * 100 : 0.0;
    return Material(
      color: Color.lerp(colors.surface, Colors.white, dark ? .04 : .85),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.onSurface.withAlpha(18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primary.withAlpha(16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: category == null
                      ? Icon(
                          Symbols.category_rounded,
                          color: colors.primary,
                          size: 22,
                        )
                      : FlowIcon(
                          category!.icon,
                          size: 22,
                          color: colors.primary,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category?.name ??
                            "tabs.stats.analytics.uncategorized".t(context),
                        style: context.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fixedAmount != null
                            ? "budget.fixedAmountLimit".t(context)
                            : percentage != null
                            ? "budget.limitRatio".t(
                                context,
                                percentage!.toStringAsFixed(2),
                              )
                            : "budget.noCategoryLimit".t(context),
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withAlpha(170),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (hasRoom)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(dark ? 20 : 12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          room.exceeded
                              ? Symbols.warning_rounded
                              : Symbols.check_circle_rounded,
                          color: statusColor,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          (room.exceeded
                                  ? "budget.categoryOverBy"
                                  : "budget.categoryRemaining")
                              .t(context),
                          style: context.textTheme.labelLarge?.copyWith(
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ExactAmountText(
                      amount: room.remaining!.abs(),
                      currency: budget.currency,
                      style: context.textTheme.headlineMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            if (!hasRoom && room.limit == null) ...[
              Text(
                "budget.categorySpent".t(context),
                style: context.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              ExactAmountText(
                amount: room.spent,
                currency: budget.currency,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (room.limit != null) ...[
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _AmountMetric(
                      label: "budget.categorySpent".t(context),
                      amount: room.spent,
                      currency: budget.currency,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AmountMetric(
                      label: "budget.categoryLimitAmount".t(context),
                      amount: room.limit!,
                      currency: budget.currency,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: room.limit == null
                    ? (usedRatio / 100).clamp(0, 1)
                    : room.progress,
                minHeight: 6,
                color: statusColor,
                backgroundColor: colors.onSurface.withAlpha(15),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "budget.usedRatio".t(context, usedRatio.toStringAsFixed(2)),
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.onSurface.withAlpha(170),
              ),
            ),
            if (missingRates)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  "budget.categoryRoomUnavailable".t(context),
                  style: context.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AmountMetric extends StatelessWidget {
  final String label;
  final Decimal amount;
  final String currency;
  const _AmountMetric({
    required this.label,
    required this.amount,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: context.textTheme.labelMedium?.copyWith(
          color: context.colorScheme.onSurface.withAlpha(170),
        ),
      ),
      const SizedBox(height: 6),
      ExactAmountText(
        amount: amount,
        currency: currency,
        style: context.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}
