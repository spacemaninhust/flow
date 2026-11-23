import "dart:convert";
import "dart:io";

import "package:flow/entity/account.dart";
import "package:flow/entity/budget.dart";
import "package:flow/objectbox/objectbox.g.dart";
import "package:flutter_test/flutter_test.dart";
// ObjectBox model metadata is used only to reproduce the previous schema.
// ignore: implementation_imports
import "package:objectbox/internal.dart" as meta;

void main() {
  test(
    "adding nullable category limits preserves existing database records",
    () async {
      final directory = await Directory.systemTemp.createTemp(
        "flow-budget-migration-",
      );
      final current = getObjectBoxModel();
      final oldJson =
          jsonDecode(
                File("lib/objectbox/objectbox-model.json").readAsStringSync(),
              )
              as Map<String, dynamic>;
      final budgetModel = (oldJson["entities"] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((e) => e["name"] == "Budget");
      (budgetModel["properties"] as List).removeWhere(
        (p) => p["name"] == "categoryLimitsJson",
      );
      budgetModel["lastPropertyId"] =
          (budgetModel["properties"] as List).last["id"];
      final legacy = Store(
        meta.ModelDefinition(meta.ModelInfo.fromMap(oldJson), current.bindings),
        directory: directory.path,
      );
      final original = Budget(
        name: "Existing budget",
        amount: 1000,
        currency: "CNY",
        range: "2026-11",
      );
      final id = legacy.box<Budget>().put(original);
      final accountId = legacy.box<Account>().put(
        Account(name: "Existing account", currency: "CNY", iconCode: "wallet"),
      );
      legacy.close();
      final upgraded = Store(getObjectBoxModel(), directory: directory.path);
      try {
        final stored = upgraded.box<Budget>().get(id)!;
        expect(stored.uuid, original.uuid);
        expect(stored.amount, 1000);
        expect(stored.categoryLimits, isEmpty);
        expect(
          upgraded.box<Account>().get(accountId)!.name,
          "Existing account",
        );
        stored.categoryLimits = {"stable-category-uuid": 25.5};
        upgraded.box<Budget>().put(stored);
        expect(upgraded.box<Budget>().get(id)!.categoryLimits, {
          "stable-category-uuid": 25.5,
        });
        stored.categoryAmountLimits = {"stable-category-uuid": 200};
        upgraded.box<Budget>().put(stored);
        final fixed = upgraded.box<Budget>().get(id)!;
        expect(fixed.categoryLimits, isEmpty);
        expect(fixed.categoryAmountLimits, {"stable-category-uuid": 200});
        fixed.amount = 5000;
        expect(fixed.categoryAmountLimits, {"stable-category-uuid": 200});
      } finally {
        upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
