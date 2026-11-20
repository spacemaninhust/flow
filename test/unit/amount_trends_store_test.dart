import "dart:io";

import "package:flow/data/amount_trend.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/objectbox.dart";
import "package:flow/services/amount_trends.dart";
import "package:flutter_test/flutter_test.dart";
import "package:uuid/uuid.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late Account account;
  late Transaction opening;

  setUpAll(() async {
    temporary = await Directory.systemTemp.createTemp("flow-trend-store-");
    await ObjectBox.initialize(
      customDirectory: temporary.path,
      subdirectory: "test",
    );
    account = Account(name: "Primary", currency: "CNY", iconCode: "wallet");
    final other = Account(name: "Other", currency: "CNY", iconCode: "wallet");
    ObjectBox().box<Account>().putMany([account, other]);
    Transaction add(
      Account owner,
      DateTime date,
      double amount, {
      bool pending = false,
      bool deleted = false,
      String? subtype,
    }) {
      final transaction = Transaction(
        uuid: const Uuid().v4(),
        currency: "CNY",
        transactionDate: date,
        amount: amount,
        isPending: pending,
        subtype: subtype,
      )..isDeleted = deleted;
      transaction.setAccount(owner);
      ObjectBox().box<Transaction>().put(transaction);
      return transaction;
    }

    opening = add(
      account,
      DateTime(2026, 1, 1),
      100.123456,
      subtype: TransactionSubtype.updateBalance.value,
    );
    add(account, DateTime(2026, 1, 31), -.1);
    add(account, DateTime(2026, 1, 31, 23, 59, 59, 999), -.2);
    add(account, DateTime(2026, 1, 31), -1000, pending: true);
    add(account, DateTime(2026, 1, 31), -1000, deleted: true);
    add(account, DateTime(2026, 2, 2), -1000);
    add(other, DateTime(2026, 1, 31), 9999);
  });

  tearDownAll(() async {
    ObjectBox().store.close();
    await temporary.delete(recursive: true);
  });

  test(
    "history includes opening adjustments and excludes unsettled records",
    () async {
      final List<AmountTrendPoint> points = await loadAccountTrend(account, [
        DateTime(2026, 2).subtract(const Duration(microseconds: 1)),
        DateTime(2026, 2, 1, 12),
      ]);
      expect(points.map((point) => point.amount.toString()), [
        "99.823456",
        "99.823456",
      ]);
    },
  );

  test(
    "editing a transaction before the visible range changes history",
    () async {
      opening.amount = 200.123456;
      ObjectBox().box<Transaction>().put(opening);
      final points = await loadAccountTrend(account, [DateTime(2026, 2, 1)]);
      expect(points.single.amount.toString(), "199.823456");
    },
  );
  test("All time starts at the first settled ledger entry", () async {
    expect(
      await firstSettledLedgerDate(accountId: account.id),
      DateTime(2026, 1, 1),
    );
    expect(await firstSettledLedgerDate(accountId: -999), isNull);
  });
}
