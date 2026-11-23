import "package:flow/data/budget_category_room.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  test("percentage limit reports the exact exceeded amount", () {
    final room = BudgetCategoryRoom(
      spent: 2500,
      budgetAmount: 10000,
      percentage: 20,
    );
    expect(room.limit.toString(), "2000");
    expect(room.remaining.toString(), "-500");
    expect(room.exceeded, isTrue);
    expect(room.progress, 1);
  });
  test(
    "fixed ceiling reports remaining money independently of budget amount",
    () {
      for (final budget in [1000.0, 5000.0]) {
        final room = BudgetCategoryRoom(
          spent: 300,
          budgetAmount: budget,
          fixedAmount: 800,
        );
        expect(room.remaining.toString(), "500");
        expect(room.exceeded, isFalse);
        expect(room.progress, .375);
      }
    },
  );
  test("at limit, zero limit, and unset limit remain distinct", () {
    final exact = BudgetCategoryRoom(
      spent: 200,
      budgetAmount: 1000,
      fixedAmount: 200,
    );
    expect(exact.remaining.toString(), "0");
    expect(exact.exceeded, isFalse);
    final zero = BudgetCategoryRoom(
      spent: .01,
      budgetAmount: 1000,
      fixedAmount: 0,
    );
    expect(zero.remaining.toString(), "-0.01");
    expect(zero.progress, 1);
    expect(BudgetCategoryRoom(spent: 20, budgetAmount: 1000).remaining, isNull);
  });
  test(
    "displayed cents suppress floating-point noise and keep visible differences",
    () {
      final noise = BudgetCategoryRoom(
        spent: .30000000000000004,
        budgetAmount: 1,
        fixedAmount: .3,
      );
      expect(noise.remaining.toString(), "0");
      expect(noise.exceeded, isFalse);
      final cents = BudgetCategoryRoom(
        spent: .305,
        budgetAmount: 1,
        fixedAmount: .304,
      );
      expect(cents.remaining.toString(), "-0.01");
    },
  );
}
