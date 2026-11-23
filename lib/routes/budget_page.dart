import "package:flow/entity/budget.dart";
import "package:flow/entity/category.dart";
import "package:flow/form_validators.dart";
import "package:flow/l10n/flow_localizations.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/actions.dart";
import "package:flow/objectbox/objectbox.g.dart";
import "package:flow/routes/error_page.dart";
import "package:flow/routes/transaction_page/input_amount_sheet.dart";
import "package:flow/services/budget.dart";
import "package:flow/services/user_preferences.dart";
import "package:flow/theme/theme.dart";
import "package:flow/utils/utils.dart";
import "package:flow/widgets/budgets/budget_category_chips.dart";
import "package:flow/widgets/delete_button.dart";
import "package:flow/widgets/general/directional_chevron.dart";
import "package:flow/widgets/general/form_close_button.dart";
import "package:flow/widgets/general/frame.dart";
import "package:flow/widgets/general/info_text.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flow/widgets/general/surface.dart";
import "package:flow/data/money.dart";
import "package:flow/widgets/sheets/select_currency_sheet.dart";
import "package:flow/widgets/time_range_selector.dart";
import "package:flow/widgets/transaction_filter_head/select_multi_category_sheet.dart";
import "package:flutter/foundation.dart" hide Category;
import "package:flutter/material.dart";
import "package:go_router/go_router.dart";
import "package:material_symbols_icons_flow/symbols.dart";
import "package:moment_dart/moment_dart.dart";

class BudgetPage extends StatefulWidget {
  final int budgetId;

  bool get isNewBudget => budgetId == 0;

  const BudgetPage({super.key, required this.budgetId});
  const BudgetPage.create({super.key}) : budgetId = 0;

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  final GlobalKey<FormState> _formKey = GlobalKey();

  late final TextEditingController _nameTextController;

  late double _amount;
  late String _currency;
  late TimeRange _timeRange;
  late bool _renewAutomatically;
  late List<Category> _categories;
  Map<String, double> _categoryLimits = {};
  Map<String, double> _categoryAmountLimits = {};
  Set<String> _fixedLimitCategories = {};

  /// The period shown when the form opened.
  ///
  /// [Budget.range] is an anchor that can sit many periods behind the live one,
  /// so [hasChanged] has to compare against what the user was actually shown —
  /// comparing against the stored anchor would report a change the moment the
  /// form opened and trap them behind a discard prompt.
  ///
  /// Not `late`: the error branch below never reaches the assignment, and an
  /// unset `late final` would throw rather than show the error page.
  String _initialRange = "";

  Budget? _currentlyEditing;

  dynamic error;

  @override
  void initState() {
    super.initState();

    _currentlyEditing = widget.isNewBudget
        ? null
        : ObjectBox().box<Budget>().get(widget.budgetId);

    // Initialize the controller unconditionally so dispose() is always safe —
    // the error branch (e.g. a since-deleted budget opened via a deep link)
    // otherwise leaves this `late final` unset and dispose() would throw.
    _nameTextController = TextEditingController(text: _currentlyEditing?.name);

    if (!widget.isNewBudget && _currentlyEditing == null) {
      error = "Budget with id ${widget.budgetId} was not found";
    } else {
      _amount = _currentlyEditing?.amount ?? 0.0;
      _currency =
          _currentlyEditing?.currency ??
          UserPreferencesService().primaryCurrency;
      // Show the period the budget is tracking right now, not its anchor — for
      // a renewing budget those diverge as soon as the first period rolls over,
      // and "July 2026" on an August budget reads as a bug.
      _timeRange = _currentlyEditing == null
          ? MonthTimeRange.fromDateTime(DateTime.now())
          : BudgetService().currentPeriod(_currentlyEditing!);
      _renewAutomatically = _currentlyEditing?.renewAutomatically ?? true;
      _categories = _currentlyEditing?.categories.toList() ?? [];
      _categoryLimits = Map.of(_currentlyEditing?.categoryLimits ?? {});
      _categoryAmountLimits = Map.of(
        _currentlyEditing?.categoryAmountLimits ?? {},
      );
      _fixedLimitCategories = _categoryAmountLimits.keys.toSet();
      _initialRange = _timeRange.toString();
    }
  }

  @override
  void dispose() {
    _nameTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) return const ErrorPage();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 40.0,
        leading: FormCloseButton(canPop: () => !hasChanged()),
        actions: [
          IconButton(
            onPressed: () => save(),
            icon: const Icon(Symbols.check_rounded),
            tooltip: "general.save".t(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                const SizedBox(height: 24.0),
                _buildHero(context),
                const SizedBox(height: 24.0),
                _buildScopeCard(context),
                Frame(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: InfoText(
                    child: Text("budget.categories.description".t(context)),
                  ),
                ),
                const SizedBox(height: 10.0),
                _buildCategoryLimits(context),
                _buildPeriodCard(context),
                if (_currentlyEditing != null) ...[
                  const SizedBox(height: 36.0),
                  Center(
                    child: DeleteButton(
                      onTap: _deleteBudget,
                      label: Text("budget.delete".t(context)),
                    ),
                  ),
                ],
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Column(
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(16.0)),
            onTap: inputAmount,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 4.0,
              ),
              child: MoneyText(
                Money(_amount, _currency),
                style: context.textTheme.displayMedium,
                autoSize: true,
                textAlign: .center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8.0),
        _buildCurrencyChip(context),
        const SizedBox(height: 12.0),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: TextFormField(
            controller: _nameTextController,
            validator: validateNameField,
            textAlign: .center,
            style: context.textTheme.titleMedium,
            decoration: InputDecoration(
              hintText: "budget.name".t(context),
              hintStyle: context.textTheme.titleMedium?.semi(context),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
              border: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.transparent),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: context.colorScheme.onSurface.withAlpha(0x30),
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.colorScheme.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrencyChip(BuildContext context) {
    return Material(
      color: context.colorScheme.onSurface.withAlpha(0x14),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: selectCurrency,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12.0, 4.0, 8.0, 4.0),
          child: Row(
            mainAxisSize: .min,
            spacing: 4.0,
            children: [
              const Icon(Symbols.universal_currency_alt_rounded, size: 16.0),
              Text(
                _currency,
                style: context.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              IconTheme.merge(
                data: const IconThemeData(size: 16.0),
                child: const LeChevron(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScopeCard(BuildContext context) {
    return Surface(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      builder: (context) => InkWell(
        borderRadius: const BorderRadius.all(Radius.circular(16.0)),
        onTap: selectCategories,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .start,
            children: [
              _buildCardHeader(
                context,
                icon: Symbols.category_rounded,
                label: "budget.scope".t(context),
                trailing: const LeChevron(),
              ),
              const SizedBox(height: 12.0),
              BudgetCategoryChips(
                categories: _categories,
                allSpendingLabel: "budget.categories.allShort".t(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodCard(BuildContext context) {
    final bool pageable = _timeRange is PageableRange;

    return Surface(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            _buildCardHeader(
              context,
              icon: Symbols.calendar_month_rounded,
              label: "budget.period".t(context),
            ),
            const SizedBox(height: 12.0),
            // The selector's month button is card-colored, so it only reads
            // against a contrasting fill. Frame it in a rounded `surface` inset
            // — the same bg/button pairing it gets on stats pages — so it looks
            // like a deliberate control group instead of a mismatched band.
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 6.0,
              ),
              decoration: BoxDecoration(
                color: context.colorScheme.surface,
                borderRadius: const BorderRadius.all(Radius.circular(12.0)),
              ),
              child: TimeRangeSelector(
                initialValue: _timeRange,
                onChanged: updateTimeRange,
                backgroundColor: Colors.transparent,
              ),
            ),
            const SizedBox(height: 4.0),
            CheckboxListTile(
              value: pageable && _renewAutomatically,
              onChanged: pageable ? updateRenewAutomatically : null,
              title: Text("budget.renewAutomatically".t(context)),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 4.0),
            InfoText(
              child: Text("budget.renewAutomatically.description".t(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryLimits(BuildContext context) {
    final categories = _categories.isEmpty
        ? ObjectBox().getCategories()
        : _categories;
    return Surface(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "budget.categoryLimits".t(context),
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              "budget.categoryLimitsHint".t(context),
              style: context.textTheme.bodySmall,
            ),
            for (final category in categories)
              Builder(
                builder: (context) {
                  final fixed = _fixedLimitCategories.contains(category.uuid);
                  final values = fixed
                      ? _categoryAmountLimits
                      : _categoryLimits;
                  return Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(category.name)),
                            DropdownButton<bool>(
                              key: ValueKey(
                                "category-limit-mode-${category.uuid}",
                              ),
                              value: fixed,
                              items: [
                                DropdownMenuItem(
                                  value: false,
                                  child: Text(
                                    "budget.limitModePercent".t(context),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text(
                                    "budget.limitModeAmount".t(context),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null || value == fixed) return;
                                final old = values[category.uuid];
                                setState(() {
                                  _categoryLimits.remove(category.uuid);
                                  _categoryAmountLimits.remove(category.uuid);
                                  if (value) {
                                    _fixedLimitCategories.add(category.uuid);
                                    if (old != null) {
                                      _categoryAmountLimits[category.uuid] =
                                          _amount * old / 100;
                                    }
                                  } else {
                                    _fixedLimitCategories.remove(category.uuid);
                                    if (old != null && _amount > 0) {
                                      _categoryLimits[category.uuid] =
                                          old / _amount * 100;
                                    }
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                        TextFormField(
                          key: ValueKey(
                            "category-${fixed ? 'amount-' : ''}limit-${category.uuid}",
                          ),
                          initialValue: values[category.uuid]?.toString(),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            hintText: "budget.noCategoryLimit".t(context),
                            suffixText: fixed ? _currency : "%",
                          ),
                          validator: (text) {
                            if (text == null || text.trim().isEmpty) {
                              return null;
                            }
                            final value = double.tryParse(
                              text.trim().replaceAll(",", "."),
                            );
                            return value == null ||
                                    !value.isFinite ||
                                    value < 0 ||
                                    (!fixed && value > 100)
                                ? (fixed
                                          ? "budget.invalidAmountLimit"
                                          : "budget.invalidCategoryLimit")
                                      .t(context)
                                : null;
                          },
                          onChanged: (text) {
                            final value = double.tryParse(
                              text.trim().replaceAll(",", "."),
                            );
                            if (text.trim().isEmpty) {
                              values.remove(category.uuid);
                            } else if (value != null &&
                                value.isFinite &&
                                value >= 0 &&
                                (fixed || value <= 100)) {
                              values[category.uuid] = value;
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Mirrors the pill header style of `InsightCard`.
  Widget _buildCardHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? trailing,
  }) {
    final Color accent = context.colorScheme.primary;

    return Row(
      children: [
        Icon(icon, color: accent, size: 20.0),
        const SizedBox(width: 8.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: accent.withAlpha(0x28),
            borderRadius: const BorderRadius.all(Radius.circular(20.0)),
          ),
          child: Text(
            label.toUpperCase(),
            style: context.textTheme.labelSmall?.copyWith(
              color: accent,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[const Spacer(), trailing],
      ],
    );
  }

  Future<void> inputAmount() async {
    final double? result = await showModalBottomSheet<double>(
      context: context,
      builder: (context) => InputAmountSheet(
        initialAmount: _amount.abs(),
        currency: _currency,
        title: "budget.amount".t(context),
        allowNegative: false,
        lockSign: true,
      ),
      isScrollControlled: true,
    );

    if (result == null) return;

    _amount = result.abs();

    if (mounted) setState(() {});
  }

  Future<void> selectCurrency() async {
    final String? result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SelectCurrencySheet(currentlySelected: _currency),
      isScrollControlled: true,
    );

    if (result == null) return;

    _currency = result;

    if (mounted) setState(() {});
  }

  Future<void> selectCategories() async {
    final Optional<List<Category>>? result =
        await showModalBottomSheet<Optional<List<Category>>>(
          context: context,
          builder: (context) => SelectMultiCategorySheet(
            categories: ObjectBox().getCategories(),
            selectedUuids: _categories
                .map((category) => category.uuid)
                .toList(),
          ),
          isScrollControlled: true,
        );

    if (result?.value case List<Category> newCategories) {
      _categories = newCategories;
      if (_categories.isNotEmpty) {
        final ids = _categories.map((c) => c.uuid).toSet();
        _categoryLimits.removeWhere((id, _) => !ids.contains(id));
        _categoryAmountLimits.removeWhere((id, _) => !ids.contains(id));
        _fixedLimitCategories.removeWhere((id) => !ids.contains(id));
      }
    }

    if (mounted) setState(() {});
  }

  void updateTimeRange(TimeRange newRange) {
    setState(() {
      _timeRange = newRange;
    });
  }

  void updateRenewAutomatically(bool? value) {
    if (value == null) return;

    setState(() {
      _renewAutomatically = value;
    });
  }

  bool hasChanged() {
    if (_currentlyEditing case Budget budget) {
      return budget.name != _nameTextController.text.trim() ||
          budget.amount != _amount ||
          budget.currency != _currency ||
          _initialRange != _timeRange.toString() ||
          budget.renewAutomatically != _renewAutomatically ||
          !mapEquals(budget.categoryLimits, _categoryLimits) ||
          !mapEquals(budget.categoryAmountLimits, _categoryAmountLimits) ||
          !setEquals(
            budget.categories.map((category) => category.uuid).toSet(),
            _categories.map((category) => category.uuid).toSet(),
          );
    }

    return _nameTextController.text.trim().isNotEmpty ||
        _amount != 0.0 ||
        _categoryLimits.isNotEmpty ||
        _categoryAmountLimits.isNotEmpty ||
        _categories.isNotEmpty;
  }

  void save() {
    if (_formKey.currentState?.validate() != true) return;

    if (_amount <= 0.0) {
      context.showErrorToast(error: "budget.amount.required".t(context));
      return;
    }

    final String trimmed = _nameTextController.text.trim();

    if (_currentlyEditing case Budget budget) {
      budget
        ..name = trimmed
        ..amount = _amount
        ..currency = _currency
        ..timeRange = _timeRange
        ..renewAutomatically = _renewAutomatically
        ..categoryLimits = _categoryLimits
        ..categoryAmountLimits = _categoryAmountLimits
        ..setCategories(_categories);

      ObjectBox().box<Budget>().put(budget, mode: PutMode.update);

      context.pop();
      return;
    }

    final Budget budget =
        Budget(
            name: trimmed,
            amount: _amount,
            currency: _currency,
            range: _timeRange.toString(),
            renewAutomatically: _renewAutomatically,
          )
          ..setCategories(_categories)
          ..categoryLimits = _categoryLimits;
    budget.categoryAmountLimits = _categoryAmountLimits;

    ObjectBox().box<Budget>().put(budget, mode: PutMode.insert);

    context.pop();
  }

  String? validateNameField(String? value) {
    final requiredValidationError = validateRequiredField(value);
    if (requiredValidationError != null) {
      return requiredValidationError.t(context);
    }

    final String trimmed = value!.trim();

    final Query<Budget> sameNameQuery = ObjectBox()
        .box<Budget>()
        .query(
          Budget_.name
              .equals(trimmed)
              .and(Budget_.id.notEquals(_currentlyEditing?.id ?? 0)),
        )
        .build();

    final bool isNameUnique = sameNameQuery.count() == 0;

    sameNameQuery.close();

    if (!isNameUnique) {
      return "error.input.duplicate.budgetName".t(context, trimmed);
    }

    return null;
  }

  Future<void> _deleteBudget() async {
    if (_currentlyEditing == null) return;

    final bool? confirmation = await context.showConfirmationSheet(
      isDeletionConfirmation: true,
      title: "general.delete.confirmName".t(context, _currentlyEditing!.name),
      child: Text("budget.delete.description".t(context)),
    );

    if (confirmation == true) {
      ObjectBox().box<Budget>().remove(_currentlyEditing!.id);

      // Only pops the editor. The detail page underneath re-reads the budget
      // when the editor returns, finds it gone, and pops itself — so the stack
      // unwinds without this route having to reason about what's below it.
      if (mounted) context.pop();
    }
  }
}
