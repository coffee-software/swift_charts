import 'dart:math' as math;

/// scale position on the rendered chart
enum ChartScalePosition { left, right }

typedef TimeChartValueFormatter = String Function(num value);

/// chart Y axis scale
class ChartScale {
  final ChartScalePosition position;
  final String textColor;
  double? min;
  double? max;
  List<double> lines;

  final TimeChartValueFormatter? valueFormatter;
  final TimeChartValueFormatter? legendFormatter;

  String formatValue(num value) {
    if (valueFormatter != null) {
      return valueFormatter!(value);
    }
    return value.toStringAsFixed(2);

    //return value.toStringAsFixed(max(0, (-((log(magnitudes[i]) / ln10) - 1)).round()));
  }

  String formatLegendValue(num value) {
    if (legendFormatter != null) {
      return legendFormatter!(value);
    }
    return formatValue(value);
  }

  ChartScale({
    required this.position,
    this.textColor = '#333',
    this.valueFormatter,
    this.legendFormatter,
    this.min,
    this.max,
    this.lines = const [],
  });

  void setLinesByStep(double step) {
    // Round away float dust (e.g. 0.30000000000000004), keyed off the
    // step's own precision.
    final decimals = math.max(0, -((math.log(step) / math.ln10).floor()) + 6);
    final factor = math.pow(10, decimals.clamp(0, 10)).toDouble();
    double clean(double v) => (v * factor).round() / factor;

    final sections = ((max! - min!) / step).round();
    lines = <double>[
      for (var i = 0; i <= sections; i++) clean(min! + step * i),
    ];

    min = clean(min!);
    max = clean(max!);
  }

  @override
  String toString() => 'ChartScale(min: $min, max: $max, lines: $lines)';
}

/// Computes "nice" chart axis bounds and gridlines for a data range.
///
/// the core rounding idea here - snapping to a step drawn
/// from {1, 2, 5, 10} × 10^n and flooring/ceiling the data bounds to that
/// step - is Paul Heckbert's "Nice Numbers for Graph Labels" algorithm
/// (Graphics Gems I, 1990).
///
/// Pipeline:
/// 1. If the data range is degenerate (min == max), fall back to a
///    nominal range centered on the value.
/// 2. Apply [minSpan]: if the data range is narrower than this, widen it.
///    Same-sign data is widened toward zero first (e.g. `[100, 100.001]`
///    with `minSpan: 10` moves min down toward 0 before moving max up);
///    data that already straddles zero is widened symmetrically.
/// 3. Apply [forceZero]: if true and the data doesn't already straddle
///    zero, pin the near-zero bound to exactly 0 (min to 0 for
///    non-negative data, max to 0 for non-positive data).
/// 4. Search "nice" steps (finest first) and floor/ceil the bounds to the
///    first step that keeps the line count within [minLines, maxLines].
///
/// This rounds to the *minimal* nice bound that covers the data (e.g. a
/// raw range of 7 becomes 8, not 10) rather than rounding the whole span
/// up to a clean number — deliberately tighter than some "nice axis"
/// examples you'll see elsewhere.
class AutoScaler {
  /// "Nice" multipliers within a decade. 2.5 is included because it's a
  /// common, clean chart step (e.g. 0, 2.5, 5, 7.5, 10) — drop it if you'd
  /// rather only ever see 1/2/5/10 steps.
  static const List<double> _niceFractions = [1, 2, 2.5, 5, 10];

  /// Computes chart-friendly axis bounds and gridlines.
  ///
  /// - [minLines] / [maxLines]: bounds on the gridline count (endpoints
  ///   included). Both must be >= 2.
  /// - [forceZero]: if true, pins the axis to include exactly 0 as a
  ///   bound whenever the data doesn't already straddle zero.
  /// - [minSpan]: the minimum allowed `max - min` *before* nice rounding.
  ///   If the data range is narrower than this, it's widened (toward
  ///   zero first for same-sign data, symmetrically otherwise). 0
  ///   disables this.
  static void autoFit(
    ChartScale scale, {
    required num dataMin,
    required num dataMax,
    int minLines = 4,
    int maxLines = 7,
    bool forceZero = false,
    double minSpan = 0,
  }) {
    assert(minLines >= 2, 'minLines must be >= 2 (need at least start/end)');
    assert(maxLines >= minLines, 'maxLines must be >= minLines');
    assert(dataMax >= dataMin, 'dataMax must be >= dataMin');
    assert(minSpan >= 0, 'minSpan must be >= 0');

    var min = dataMin.toDouble();
    var max = dataMax.toDouble();

    // Degenerate case: no data range at all (a single point, or every
    // value identical). There's no objectively "correct" answer, so we
    // fall back to a small nominal span centered on the value.
    if (max - min <= 0) {
      final nominalRange = max == 0 ? 1.0 : max.abs();
      min -= nominalRange / 2;
      max += nominalRange / 2;
    }

    if (minSpan > 0) {
      final result = _applyMinSpan(min, max, minSpan);
      min = result.$1;
      max = result.$2;
    }

    if (forceZero) {
      final result = _applyForceZero(min, max);
      min = result.$1;
      max = result.$2;
    }

    final step = _chooseStep(min, max, minLines, maxLines);
    final niceMin = (min / step).floor() * step;
    final niceMax = (max / step).ceil() * step;

    scale.min = niceMin;
    scale.max = niceMax;
    scale.setLinesByStep(step);
  }

  /// Widens [min]..[max] to at least [minSpan]. Same-sign ranges are
  /// widened toward zero first; ranges already straddling zero are
  /// widened symmetrically.
  static (double, double) _applyMinSpan(double min, double max, double minSpan) {
    final span = max - min;
    if (span >= minSpan) return (min, max);
    final deficit = minSpan - span;

    if (min >= 0 && max >= 0) {
      final pushDown = math.min(deficit, min);
      return (min - pushDown, max + (deficit - pushDown));
    }
    if (min <= 0 && max <= 0) {
      final pushUp = math.min(deficit, -max);
      return (min - (deficit - pushUp), max + pushUp);
    }
    // Already straddles zero: widen evenly on both sides.
    final half = deficit / 2;
    return (min - half, max + half);
  }

  /// Pins the near-zero bound to exactly 0, unless the range already
  /// straddles zero (in which case 0 is already included).
  static (double, double) _applyForceZero(double min, double max) {
    if (min >= 0) return (0, max);
    if (max <= 0) return (min, 0);
    return (min, max);
  }

  static double _chooseStep(double min, double max, int minLines, int maxLines) {
    final range = max - min;
    final candidates = _candidateSteps(range <= 0 ? 1 : range);

    (double step, int count)? bestOutOfRange;
    var bestDiff = 1 << 30;

    for (final step in candidates) {
      final niceMin = (min / step).floor() * step;
      final niceMax = (max / step).ceil() * step;
      final count = ((niceMax - niceMin) / step).round() + 1;
      if (count >= minLines && count <= maxLines) return step;

      final diff = count < minLines ? minLines - count : count - maxLines;
      if (diff < bestDiff) {
        bestDiff = diff;
        bestOutOfRange = (step, count);
      }
    }
    // Nothing landed exactly inside [minLines, maxLines] (can happen with
    // unusual configs) — fall back to whichever nice step got closest.
    return bestOutOfRange!.$1;
  }

  /// "Nice" step candidates spanning a few orders of magnitude around
  /// [range], ascending (finest/most-lines first). A few magnitudes is
  /// enough for any realistic minLines/maxLines window; it isn't an
  /// exhaustive search by design (pareto: good enough, not exhaustive).
  static List<double> _candidateSteps(double range) {
    final steps = <double>{};
    final topExponent = (math.log(range) / math.ln10).ceil();
    for (var e = topExponent; e >= topExponent - 3; e--) {
      final magnitude = math.pow(10, e).toDouble();
      for (final f in _niceFractions) {
        steps.add(f * magnitude);
      }
    }
    final result = steps.toList()..sort();
    return result;
  }
}
