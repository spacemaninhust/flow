import "dart:convert";

import "package:flow/entity/_base.dart";
import "package:flow/entity/category.dart";
import "package:flow/utils/json/time_range_converter.dart";
import "package:flow/utils/json/utc_datetime_converter.dart";
import "package:json_annotation/json_annotation.dart";
import "package:moment_dart/moment_dart.dart";
import "package:objectbox/objectbox.dart";
import "package:uuid/uuid.dart";

part "budget.g.dart";

@Entity()
@JsonSerializable(
  explicitToJson: true,
  converters: [UTCDateTimeConverter(), TimeRangeConverter()],
)
class Budget implements EntityBase {
  @JsonKey(includeFromJson: false, includeToJson: false)
  int id;

  @override
  @Unique()
  String uuid;

  @Property(type: PropertyType.date)
  DateTime createdDate;

  @Unique()
  String name;

  /// [moment_dart](https://pub.dev/packages/moment_dart)'s [TimeRange]
  /// compliant string.
  ///
  /// An **anchor**, not a moving window: it records one period of the budget's
  /// series and is never rewritten as periods roll over. Ask
  /// `BudgetService.currentPeriod` for the period being tracked right now.
  String range;

  @Transient()
  TimeRange get timeRange => TimeRange.parse(range);

  set timeRange(TimeRange value) => range = value.toString();

  /// When [true], and [timeRange] is [PageableRange], the budget follows its
  /// series — the tracked period is derived from [range] and the current
  /// moment, so it rolls over on its own. When [false], the budget is a
  /// one-off that stays on [range] forever.
  ///
  /// Nothing is written either way. See `BudgetService.currentPeriod`.
  bool renewAutomatically;

  double amount;

  String currency;

  /// Nullable additive storage; older databases have no category limits.
  @JsonKey(includeFromJson: false, includeToJson: false)
  String? categoryLimitsJson;

  Map<String, dynamic> _readCategoryLimits() =>
      categoryLimitsJson == null || categoryLimitsJson!.isEmpty
      ? {}
      : jsonDecode(categoryLimitsJson!) as Map<String, dynamic>;

  /// Percentage ceilings keyed by stable category UUID, also included in backups.
  @Transient()
  @JsonKey(defaultValue: <String, double>{})
  Map<String, double> get categoryLimits {
    return Map.fromEntries(
      _readCategoryLimits().entries
          .where((entry) => entry.value is num)
          .map((entry) => MapEntry(entry.key, (entry.value as num).toDouble())),
    );
  }

  set categoryLimits(Map<String, double> value) {
    if (value.values.any((v) => !v.isFinite || v < 0 || v > 100)) {
      throw ArgumentError("Category limits must be percentages from 0 to 100");
    }
    final map = _readCategoryLimits()..removeWhere((_, v) => v is num);
    map.addAll(value);
    categoryLimitsJson = map.isEmpty ? null : jsonEncode(map);
  }

  /// Fixed monetary ceilings in the budget currency; independent of its amount.
  @Transient()
  @JsonKey(defaultValue: <String, double>{})
  Map<String, double> get categoryAmountLimits => Map.fromEntries(
    _readCategoryLimits().entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) =>
              MapEntry(entry.key, (entry.value["amount"] as num).toDouble()),
        ),
  );

  set categoryAmountLimits(Map<String, double> value) {
    if (value.values.any((v) => !v.isFinite || v < 0)) {
      throw ArgumentError(
        "Category amount limits must be finite and nonnegative",
      );
    }
    final map = _readCategoryLimits()..removeWhere((_, v) => v is Map);
    map.addAll(value.map((key, amount) => MapEntry(key, {"amount": amount})));
    categoryLimitsJson = map.isEmpty ? null : jsonEncode(map);
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  final categories = ToMany<Category>();

  @Transient()
  List<String>? _categoriesUuids;

  List<String>? get categoriesUuids =>
      _categoriesUuids ?? categories.map((e) => e.uuid).toList();

  set categoriesUuids(List<String>? newTagUuids) {
    _categoriesUuids = newTagUuids ?? <String>[];
  }

  void setCategories(List<Category>? newCategories) {
    categories.clear();
    categories.addAll(newCategories ?? []);
    categoriesUuids = categories.map((e) => e.uuid).toList();
  }

  Budget({
    this.id = 0,
    required this.name,
    required this.amount,
    required this.currency,
    required this.range,
    this.renewAutomatically = true,
    DateTime? createdDate,
  }) : createdDate = createdDate ?? DateTime.now(),
       uuid = const Uuid().v4();

  factory Budget.fromJson(Map<String, dynamic> json) => _$BudgetFromJson(json);
  Map<String, dynamic> toJson() => _$BudgetToJson(this);
}
