import "package:flow/data/exchange_rates.dart";
import "package:flow/data/money.dart";
import "package:flow/entity/budget.dart";
import "package:flow/entity/category.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/services/budget.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flutter/material.dart";

/// Explains category usage against the budget amount and each configured cap.
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
    final limits = budget.categoryLimits;
    final amountLimits = budget.categoryAmountLimits;
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "budget.categoryUsage".t(context),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            "budget.categoryUsageHint".t(context),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final row in rows) ...[
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final cap = limits[row.category?.uuid];
                final fixedCap = amountLimits[row.category?.uuid];
                final capAmount =
                    fixedCap ??
                    (cap == null ? null : budget.amount * cap / 100);
                final percentage = budget.amount > 0
                    ? row.amount / budget.amount * 100
                    : 0.0;
                final exceeded = capAmount != null && row.amount > capAmount;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            row.category?.name ??
                                "tabs.stats.analytics.uncategorized".t(context),
                          ),
                        ),
                        MoneyText(
                          Money(row.amount, budget.currency),
                          autoSize: true,
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        Text(
                          "budget.usedRatio".t(
                            context,
                            percentage.toStringAsFixed(2),
                          ),
                        ),
                        Text(
                          fixedCap != null
                              ? "budget.fixedAmountLimit".t(context)
                              : cap == null
                              ? "budget.noCategoryLimit".t(context)
                              : "budget.limitRatio".t(
                                  context,
                                  cap.toStringAsFixed(2),
                                ),
                        ),
                        if (exceeded)
                          Text(
                            "budget.categoryExceeded".t(context),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                    if (capAmount != null)
                      Row(
                        children: [
                          Text("budget.categoryLimitAmount".t(context)),
                          const SizedBox(width: 8),
                          MoneyText(Money(capAmount, budget.currency)),
                        ],
                      ),
                    if (row.missing)
                      Text(
                        "tabs.stats.analytics.missingRatesAmounts".t(context),
                      ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: (percentage / 100).clamp(0, 1),
                      color: exceeded
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
