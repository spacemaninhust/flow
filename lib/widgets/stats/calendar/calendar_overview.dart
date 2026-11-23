import "package:decimal/decimal.dart";
import "package:flow/data/money.dart";
import "package:flow/data/spending_statistics.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/widgets/stats/exact_amount_text.dart";
import "package:flutter/material.dart";

/// The calendar's primary visual anchor: total spending and elapsed-day average.
class CalendarOverview extends StatelessWidget {
  final Money total;
  final int days;
  final String label;

  const CalendarOverview({
    super.key,
    required this.total,
    required this.days,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = colors.onPrimary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withAlpha(35),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: text.withAlpha(220),
            ),
          ),
          const SizedBox(height: 8),
          ExactAmountText(
            amount: Decimal.parse(total.amount.toString()),
            currency: total.currency,
            style: theme.textTheme.displaySmall?.copyWith(
              color: text,
              fontSize: 36,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: text.withAlpha(45)),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "stats.dailyAverage".t(context),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: text.withAlpha(220),
                      ),
                    ),
                    const SizedBox(height: 6),
                    ExactAmountText(
                      amount: Decimal.parse(
                        dailySpendingAverage(total.amount, days).toString(),
                      ),
                      currency: total.currency,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "calendar.elapsed".t(context),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: text.withAlpha(220),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "calendar.dayCount".t(context, days),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "calendar.averageHint".t(context),
            style: theme.textTheme.bodySmall?.copyWith(
              color: text.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}
