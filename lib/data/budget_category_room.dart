import "package:decimal/decimal.dart";

/// Monetary room at the same cent precision as the displayed category amounts.
class BudgetCategoryRoom {
  final Decimal spent;
  final Decimal? limit;

  BudgetCategoryRoom({
    required double spent,
    required double budgetAmount,
    double? percentage,
    double? fixedAmount,
  }) : spent = Decimal.parse(spent.toString()),
       limit = fixedAmount != null
           ? Decimal.parse(fixedAmount.toString())
           : percentage == null
           ? null
           : Decimal.parse(budgetAmount.toString()) *
                 Decimal.parse(percentage.toString()) *
                 Decimal.parse("0.01");

  Decimal? get remaining =>
      limit == null ? null : limit!.round(scale: 2) - spent.round(scale: 2);
  bool get exceeded => remaining != null && remaining! < Decimal.zero;

  /// Progress is relative to the category ceiling, rather than the whole budget.
  double get progress {
    if (limit == null) return 0;
    if (limit! <= Decimal.zero) return spent > Decimal.zero ? 1 : 0;
    return (spent.toDouble() / limit!.toDouble()).clamp(0, 1);
  }
}
