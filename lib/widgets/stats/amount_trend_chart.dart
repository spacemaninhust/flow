import "dart:math" as math;

import "package:fl_chart/fl_chart.dart";
import "package:flow/data/amount_trend.dart";
import "package:flow/data/money.dart";
import "package:flow/data/trend_axis_labels.dart";
import "package:flow/l10n/extensions.dart";
import "package:flow/widgets/general/money_text.dart";
import "package:flow/widgets/stats/exact_amount_text.dart";
import "package:flutter/material.dart";
import "package:moment_dart/moment_dart.dart";

/// Shared point selection, money labels and calendar ticks.
class AmountTrendChart extends StatefulWidget {
  final List<AmountTrendPoint> points;
  final String currency;
  final bool monthly;
  final ValueChanged<AmountTrendPoint>? onSelected;
  final double height;

  const AmountTrendChart({
    super.key,
    required this.points,
    required this.currency,
    this.monthly = false,
    this.onSelected,
    this.height = 220,
  });

  @override
  State<AmountTrendChart> createState() => _AmountTrendChartState();
}

class _AmountTrendChartState extends State<AmountTrendChart> {
  int? selected;

  @override
  void didUpdateWidget(covariant AmountTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) selected = null;
  }

  void _select(int index) {
    setState(() => selected = index);
    widget.onSelected?.call(widget.points[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text("trend.noData".t(context)),
      );
    }
    final int index = selected ?? widget.points.length - 1;
    final AmountTrendPoint point = widget.points[index];
    final Color color = Theme.of(context).colorScheme.primary;
    final List<double> values = widget.points
        .map((point) => point.amount.toDouble())
        .toList();
    final double low = values.reduce(math.min);
    final double high = values.reduce(math.max);
    final double pad = high == low ? high.abs() * .1 + 1 : (high - low) * .15;
    final Map<double, Set<int>> axisLabels = {};
    String axisLabel(int i) => widget.points[i].date.toMoment().format(
      widget.monthly ? "MMM" : "MMM D",
    );
    final labelStyle = Theme.of(context).textTheme.labelSmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          point.date.toMoment().format(
            widget.monthly ? "YYYY-MM" : "YYYY-MM-DD",
          ),
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 4),
        Semantics(
          liveRegion: true,
          child: ExactAmountText(
            amount: point.amount,
            currency: widget.currency,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "trend.touchHint".t(context),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: widget.height,
          child: LineChart(
            duration: Duration.zero,
            LineChartData(
              minX: 0,
              maxX: math.max(1, values.length - 1).toDouble(),
              minY: low - pad,
              maxY: high + pad,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: false,
                touchCallback: (event, response) {
                  if (event is! FlTapUpEvent &&
                      event is! FlPanUpdateEvent &&
                      event is! FlLongPressMoveUpdate &&
                      event is! FlLongPressStart) {
                    return;
                  }
                  final spots = response?.lineBarSpots;
                  if (spots == null || spots.isEmpty) return;
                  _select(spots.first.spotIndex);
                },
              ),
              showingTooltipIndicators: [],
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 48,
                    getTitlesWidget: (value, meta) {
                      if (value != meta.min && value != meta.max) {
                        return const SizedBox.shrink();
                      }
                      return MoneyText(
                        Money(value, widget.currency),
                        initiallyAbbreviated: true,
                        autoSize: true,
                        style: Theme.of(context).textTheme.labelSmall,
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      final int i = value.round();
                      if (value != i.toDouble() ||
                          i < 0 ||
                          i >= values.length ||
                          !axisLabels
                              .putIfAbsent(
                                meta.parentAxisSize,
                                () => trendAxisLabels(
                                  count: values.length,
                                  width: meta.parentAxisSize,
                                  labelWidth: (index) {
                                    final painter = TextPainter(
                                      text: TextSpan(
                                        text: axisLabel(index),
                                        style: labelStyle,
                                      ),
                                      textDirection: Directionality.of(context),
                                      textScaler: MediaQuery.textScalerOf(
                                        context,
                                      ),
                                    )..layout();
                                    final width = painter.width;
                                    painter.dispose();
                                    return width;
                                  },
                                ),
                              )
                              .contains(i)) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                        child: Text(axisLabel(i), style: labelStyle),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(drawVerticalLine: false),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  bottom: BorderSide(color: color.withAlpha(90), width: 2),
                  left: BorderSide(color: color.withAlpha(90), width: 2),
                ),
              ),
              extraLinesData: ExtraLinesData(
                verticalLines: [
                  VerticalLine(
                    x: index.toDouble(),
                    color: color.withAlpha(90),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ],
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: values
                      .asMap()
                      .entries
                      .map((entry) => FlSpot(entry.key.toDouble(), entry.value))
                      .toList(),
                  color: color,
                  barWidth: 2.5,
                  showingIndicators: [index],
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, bar) => spot.x == index,
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: color.withAlpha(20),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: "trend.previousPoint".t(context),
              onPressed: index > 0 ? () => _select(index - 1) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text("${index + 1} / ${widget.points.length}"),
            IconButton(
              tooltip: "trend.nextPoint".t(context),
              onPressed: index < values.length - 1
                  ? () => _select(index + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
