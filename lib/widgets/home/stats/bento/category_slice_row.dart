import "package:flow/data/money.dart";
import "package:flow/data/spending_statistics.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/theme/theme.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flutter/material.dart";

/// One category's spend in the top-categories tile: a name, amount, and a bar
/// sized by the category's share of the largest spender ([maxAmount]).
class CategorySliceRow extends StatelessWidget {
  final String name;
  final double amount;
  final Color color;
  final double maxAmount;
  final String currency;
  final int? averageDays;

  const CategorySliceRow({
    super.key,
    required this.name,
    required this.amount,
    required this.color,
    required this.maxAmount,
    required this.currency,
    this.averageDays,
  });

  @override
  Widget build(BuildContext context) {
    final double factor = maxAmount <= 0
        ? 0.0
        : (amount / maxAmount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 6.0),
            Flexible(
              child: MoneyText(
                Money(amount, currency),
                style: context.textTheme.labelSmall?.semi(context),
                autoSize: true,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        if (averageDays != null)
          Row(
            children: [
              Text(
                "stats.dailyAverage".t(context),
                style: context.textTheme.labelSmall,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: MoneyText(
                  Money(dailySpendingAverage(amount, averageDays!), currency),
                  autoSize: true,
                  style: context.textTheme.labelSmall,
                ),
              ),
            ],
          ),
        const SizedBox(height: 3.0),
        ClipRRect(
          borderRadius: .all(Radius.circular(3.0)),
          child: LinearProgressIndicator(
            value: factor,
            minHeight: 5.0,
            backgroundColor: context.colorScheme.onSurface.withAlpha(0x1a),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
