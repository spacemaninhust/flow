import "dart:math" as math;

/// Chooses calendar ticks using their fitted positions, reserving the last date.
/// Labels close to the last date are omitted rather than painted on top of it.
Set<int> trendAxisLabels({
  required int count,
  required double width,
  required double Function(int index) labelWidth,
}) {
  if (count == 0 || width <= 0) return {};
  if (count == 1) return {0};
  const double gap = 10;
  const double edge = 6;
  (double, double) bounds(int i) {
    final w = math.min(labelWidth(i), width);
    final center = (width * i / (count - 1)).clamp(w / 2, width - w / 2);
    final left = (center - w / 2).clamp(edge, math.max(edge, width - w - edge));
    return (left.toDouble(), (left + w).toDouble());
  }

  final last = count - 1;
  final lastLeft = bounds(last).$1;
  final selected = <int>{last};
  double right = -gap;
  final step = math.max(1, (count / 4).floor());
  for (int i = 0; i < last; i += step) {
    final (left, nextRight) = bounds(i);
    if (left >= right + gap && nextRight + gap <= lastLeft) {
      selected.add(i);
      right = nextRight;
    }
  }
  return selected;
}
