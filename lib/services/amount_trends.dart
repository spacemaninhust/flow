import "package:decimal/decimal.dart";
import "package:flow/data/amount_trend.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/objectbox.g.dart";

/// Bounds the All time selector to recorded history instead of the date sentinel.
Future<DateTime?> firstSettledLedgerDate({int? accountId}) async {
  Condition<Transaction> condition =
      Transaction_.transactionDate.lessOrEqualDate(DateTime.now()) &
      (Transaction_.isPending.isNull() |
          Transaction_.isPending.notEquals(true)) &
      (Transaction_.isDeleted.isNull() |
          Transaction_.isDeleted.notEquals(true));
  if (accountId != null) condition &= Transaction_.account.equals(accountId);
  final query = ObjectBox()
      .box<Transaction>()
      .query(condition)
      .order(Transaction_.transactionDate)
      .build();
  try {
    return (await query.findFirstAsync())?.transactionDate;
  } finally {
    query.close();
  }
}

/// Reads each account ledger once instead of querying once per plotted point.
Future<List<AmountTrendPoint>> loadAccountTrend(
  Account account,
  List<DateTime> anchors,
) async {
  if (anchors.isEmpty) return [];
  final Query<Transaction> query = ObjectBox()
      .box<Transaction>()
      .query(
        Transaction_.account.equals(account.id) &
            Transaction_.transactionDate.lessOrEqualDate(anchors.last) &
            (Transaction_.isPending.isNull() |
                Transaction_.isPending.notEquals(true)) &
            (Transaction_.isDeleted.isNull() |
                Transaction_.isDeleted.notEquals(true)),
      )
      .build();
  try {
    final List<Transaction> transactions = await query.findAsync();
    return balanceTrend(
      transactions.map(
        (transaction) => (
          date: transaction.transactionDate,
          amount: Decimal.parse(transaction.amount.toString()),
        ),
      ),
      anchors,
    );
  } finally {
    query.close();
  }
}
