import "dart:async";

import "package:flow/data/amount_trend.dart";
import "package:flow/entity/account.dart";
import "package:flow/entity/transaction.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/objectbox.dart";
import "package:flow/objectbox/objectbox.g.dart";
import "package:flow/services/amount_trends.dart";
import "package:flow/widgets/stats/amount_trend_chart.dart";
import "package:flutter/material.dart";
import "package:moment_dart/moment_dart.dart";

/// Live account history; watches the entire ledger so opening balances refresh.
class AccountBalanceTrend extends StatefulWidget {
  final Account account;
  final TimeRange range;

  const AccountBalanceTrend({
    super.key,
    required this.account,
    required this.range,
  });

  @override
  State<AccountBalanceTrend> createState() => _AccountBalanceTrendState();
}

class _AccountBalanceTrendState extends State<AccountBalanceTrend> {
  StreamSubscription<Query<Transaction>>? subscription;
  Timer? debounce;
  List<AmountTrendPoint>? points;
  Object? error;
  int generation = 0;

  // DateTime.difference overflows microseconds for the All time sentinels.
  bool get monthly =>
      widget.range.to.millisecondsSinceEpoch -
          widget.range.from.millisecondsSinceEpoch >
      const Duration(days: 62).inMilliseconds;

  @override
  void initState() {
    super.initState();
    _watch();
  }

  void _watch() {
    subscription?.cancel();
    subscription = ObjectBox()
        .box<Transaction>()
        .query(Transaction_.account.equals(widget.account.id))
        .watch()
        .listen((_) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 150), _load);
        });
    _load();
  }

  @override
  void didUpdateWidget(covariant AccountBalanceTrend oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account.id != widget.account.id) {
      _watch();
    } else if (oldWidget.range != widget.range ||
        oldWidget.account != widget.account) {
      _load();
    }
  }

  Future<void> _load() async {
    final int request = ++generation;
    try {
      final DateTime from = widget.range.from <= Moment.minValue
          ? await firstSettledLedgerDate(accountId: widget.account.id) ??
                DateTime.now()
          : widget.range.from;
      final anchors = trendAnchors(
        from: from,
        to: widget.range.to,
        now: DateTime.now(),
        monthly: monthly,
      );
      final result = await loadAccountTrend(widget.account, anchors);
      if (!mounted || request != generation) return;
      setState(() {
        points = result;
        error = null;
      });
    } catch (e) {
      if (!mounted || request != generation) return;
      setState(() => error = e);
    }
  }

  @override
  void dispose() {
    generation++;
    subscription?.cancel();
    debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        "trend.accountBalance".t(context),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      if (error != null)
        TextButton(onPressed: _load, child: Text("trend.retry".t(context)))
      else if (points == null)
        const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        )
      else
        AmountTrendChart(
          points: points!,
          currency: widget.account.currency,
          monthly: monthly,
        ),
    ],
  );
}
