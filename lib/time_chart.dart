import 'dart:js_interop';
import 'dart:math';
import 'dart:async';

import 'chart_data.dart';
import 'chart_colors.dart';

import 'swift_charts.dart';
import 'package:web/web.dart';

typedef TimeChartValueFormatter = String Function(num value);
typedef TimeChartDateFormatter = String Function(DateTime date);

enum TimeChartDateDisplay {
  utc,
  local,
  both
}

enum IntervalAlignment {
  start,
  end,
  center
}

sealed class TimeChartSeries {
  late String color;

  ChartScalePosition? scalePosition;
  ChartScale? scale;
  ChartTransform? transform;
  num minValue = 0;
  num maxValue = 0;

  /// calculated from data if not passed
  Duration? interval;

  /*
  DateTimeRange resolveInterval(DateTime key, Duration interval, IntervalAlignment a) => switch (a) {
    IntervalAlignment.end   => DateTimeRange(start: key.subtract(interval), end: key),
    IntervalAlignment.start => DateTimeRange(start: key, end: key.add(interval)),
    IntervalAlignment.center => DateTimeRange(start: key.subtract(interval ~/ 2), end: key.add(interval ~/ 2)),
  };*/

  ///
  IntervalAlignment? alignment;


  late ObservableMap<int, num> _data;

  /// Set by the chart when this series is attached, so mutations reach it.
  void Function()? _notify;

  Map<int, num> get data => _data;

  set data(Map<int, num> value) {
    _data = ObservableMap(Map.of(value), () => _notify?.call());
    _notify?.call();
  }

  Iterable<({double x, double y, bool isActive})> transformedPoints(SwiftTimeChart chart) sync* {
    for (var k in data.keys) {
      final transformed = transform!.apply(k, data[k]!.toDouble());
      yield (x: transformed.x, y: transformed.y, isActive: chart.currentTime == k);
    }
  }

  TimeChartSeries({
    required Map<int, num> data,
    this.scale,
    this.scalePosition,
    String? color,
    this.interval,
    this.alignment,
    this.valueTitle = 'value',
    this.valueFormatter,
    this.legendFormatter
  }) {
    this.color = color ?? ColorGenerator.nextColor();
// wire the wrapper's callback to route through our own notify hook
    _data = ObservableMap(Map.of(data), () => _notify?.call());
  }

  TimeChartValueFormatter? valueFormatter;
  TimeChartValueFormatter? legendFormatter;

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

  //todo: remove
  List<double> valueLabels = [];

  int minSpread = 1;
  String valueTitle;

  void render(SwiftTimeChart chart, CanvasRenderingContext2D ctx);
}

class LineSeries extends TimeChartSeries {

  String? shadowColor;
  int lineWidth;
  int pointRadius;
  int? hoverPointRadius;

  double smoothing;

  LineSeries(
      {required super.data,
      super.scale,
      super.color,
      super.interval,
      super.alignment,
      super.valueTitle = 'value',
      super.valueFormatter,
      super.legendFormatter,
      super.scalePosition,
      this.smoothing = 0.0,
      this.lineWidth = 1,
      this.pointRadius = 2,
      this.hoverPointRadius,
      String? shadowColor}) {
    this.shadowColor = shadowColor ?? (color.startsWith('#') ? color + '11' : null);
  }

  @override
  void render(SwiftTimeChart chart, CanvasRenderingContext2D ctx) {
//shadow!
    if (shadowColor != null) {
      ctx.beginPath();
      ctx.fillStyle = shadowColor!.toJS;
      ({double x, double y, bool isActive})? previous;
      for (var point in transformedPoints(chart)) {
        if (previous == null) {
          ctx.moveTo(point.x, point.y);
        } else {
          if (smoothing > 0) {
            Point cp1 = Point((previous.x + point.x) / 2, previous.y);
            Point cp2 = Point((previous.x + point.x) / 2, point.y);
            ctx.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, point.x, point.y);
          } else {
            ctx.lineTo(point.x, point.y);
          }
        }
        previous = point;
      }
      // close down to the baseline and back
      ctx.lineTo(chart.leftMargin + chart.chartWidth, chart.topMargin + chart.chartHeight);
      ctx.lineTo(chart.leftMargin, chart.topMargin + chart.chartHeight);
      ctx.closePath();
      ctx.fill();
    }

    ctx.beginPath();
    ctx.strokeStyle = color.toJS;
    ctx.fillStyle = color.toJS;
    ctx.lineWidth = lineWidth;

    ({double x, double y, bool isActive})? previous;
    for (var point in transformedPoints(chart)) {
      if (previous == null) {
        ctx.moveTo(point.x, point.y);
      } else {
        if (smoothing > 0) {
          Point cp1 = Point((previous.x + point.x) / 2, previous.y);
          Point cp2 = Point((previous.x + point.x) / 2, point.y);

          ctx.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, point.x, point.y);
        } else {
          ctx.lineTo(point.x, point.y);
        }
      }
      previous = point;
    }
    ctx.stroke();

    for (var point in transformedPoints(chart)) {
      ctx.beginPath();
      if (point.isActive) {
        ctx.arc(point.x, point.y, hoverPointRadius ?? (pointRadius + 2), 0, 2 * pi);
      } else {
        ctx.arc(point.x, point.y, pointRadius, 0, 2 * pi);
      }
      ctx.stroke();
      ctx.fill();
    }
  }
}

class BarSeries extends TimeChartSeries {

  String strokeColor;
  String? hoverColor;
  int strokeWidth;
  int borderRadius;

  double? barWidth;

  int numBars = 0;
  int barIndex = 0;

  BarSeries(
      {required super.data,
      super.scale,
      super.color,
      super.interval,
      super.alignment,
      super.valueTitle = 'value',
      super.valueFormatter,
      super.legendFormatter,
      super.scalePosition,
      this.hoverColor,
      this.strokeColor = '#0007',
      this.strokeWidth = 0,
      this.borderRadius = 0,
      this.barWidth,
      });

  @override
  void render(SwiftTimeChart chart, CanvasRenderingContext2D ctx) {
    ctx.strokeStyle = strokeColor.toJS;
    ctx.lineWidth = strokeWidth;
    ctx.fillStyle = color.toJS;

    final maxWidth = transform!.apply(interval!.inMilliseconds, 0).x - transform!.apply(0, 0).x;
    final width = (barWidth ?? (0.65 / numBars)) * maxWidth;

    for (var point in transformedPoints(chart)) {
      ctx.fillStyle = point.isActive ? (hoverColor ?? color).toJS : color.toJS;

      double w = point.isActive ? width + 2 : width;
      final offset = (barIndex * w) - ((w * numBars) / 2);

      if (chart.chartHeight + chart.topMargin > point.y) {
        /*ctx.roundRect(point.x - (w / 2), point.y, w, chart.chartHeight + chart.topMargin - point.y);
          CanvasRenderingContext2D.fill] or [CanvasRenderingContext2D.stroke*/

        if (true /*ctx.hasProperty('roundRect'.toJS)*/) {
          ctx.beginPath();
          ctx.roundRect(point.x + offset, point.y, w, chart.chartHeight + chart.topMargin - point.y, <JSAny?>[borderRadius.toJS, borderRadius.toJS, 0.toJS, 0.toJS].toJS);
          ctx.fill();
          if (strokeWidth > 0) {
            ctx.stroke();
          }
        } else {
          //old safari fallback
          ctx.fillRect(point.x + offset, point.y, w, chart.chartHeight + chart.topMargin - point.y);
        }
        //ctx.strokeRect(point.x + offset, point.y, w, chart.chartHeight + chart.topMargin - point.y);
      }
    }
  }
}

/// pan/zoom transformation that will convert time and value into x y
class ChartTransform {
  final double sx, tx, sy, ty;
  const ChartTransform({required this.sx, required this.tx, required this.sy, required this.ty});

  factory ChartTransform.forScale({
    required int minTime,
    required int maxTime,
    required int width,
    required int leftMargin,
    required double minValue,
    required double maxValue,
    required int height,
    required int topMargin,
  }) {
    final sx = (width) / (maxTime - minTime);
    final tx = leftMargin - sx * minTime;

    final rawSy = (height) / (maxValue - minValue);
    final sy = -rawSy;
    final ty = height + topMargin + rawSy * minValue;

    return ChartTransform(sx: sx, tx: tx, sy: sy, ty: ty);
  }

  ({double x, double y}) apply(int time, double value) => (x: sx * time + tx, y: sy * value + ty);
}

/// Find X axis labels
enum _Unit { second, minute, hour, day, month, year }

String _2(int n) => n.toString().padLeft(2, '0');
const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const _weekdays = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun']; // DateTime.weekday: Mon=1..Sun=7

/// Constructs a DateTime in either UTC or local, keeping calendar arithmetic
/// consistent with whichever clock we're aligning ticks to. Mixing the two
/// (e.g. building a "local" DateTime from a UTC one's y/m/d fields) is a
/// classic subtle bug, so every _Step method threads `utc` through explicitly.
DateTime _make(bool utc, int y, int m, int d, [int h = 0, int mi = 0, int s = 0]) =>
    utc ? DateTime.utc(y, m, d, h, mi, s) : DateTime(y, m, d, h, mi, s);

class _Step {
  final _Unit unit;
  final int mult;
  final String Function(DateTime) format;
  const _Step(this.unit, this.mult, this.format);

  /// Approximate size, used ONLY to pick which step to use. Never used to
  /// place ticks directly — actual placement always walks the calendar via
  /// [next], so this being approximate for day/month/year is fine.
  int get approxMs {
    switch (unit) {
      case _Unit.second: return mult * 1000;
      case _Unit.minute: return mult * 60 * 1000;
      case _Unit.hour:   return mult * 60 * 60 * 1000;
      case _Unit.day:    return mult * 24 * 60 * 60 * 1000;
      case _Unit.month:  return mult * 30 * 24 * 60 * 60 * 1000;
      case _Unit.year:   return mult * 365 * 24 * 60 * 60 * 1000;
    }
  }

  /// Rounds DOWN to the nearest aligned tick at-or-before [d].
  DateTime floor(DateTime d, bool utc) {
    switch (unit) {
      case _Unit.second: return _make(utc, d.year, d.month, d.day, d.hour, d.minute, (d.second ~/ mult) * mult);
      case _Unit.minute: return _make(utc, d.year, d.month, d.day, d.hour, (d.minute ~/ mult) * mult);
      case _Unit.hour:   return _make(utc, d.year, d.month, d.day, (d.hour ~/ mult) * mult);
      case _Unit.day:    return _make(utc, d.year, d.month, d.day);
      case _Unit.month:  return _make(utc, d.year, ((d.month - 1) ~/ mult) * mult + 1, 1);
      case _Unit.year:   return _make(utc, (d.year ~/ mult) * mult, 1, 1);
    }
  }

  /// Calendar-aware advance. Seconds/minutes/hours use Duration (they're
  /// true fixed-length units, always safe). Day/month/year use the DateTime
  /// component constructor, which normalizes overflow via real calendar
  /// rules — this is what survives DST (23h/25h days), variable month
  /// lengths, and leap years without any special-casing here.
  DateTime next(DateTime d, bool utc) {
    switch (unit) {
      case _Unit.second: return d.add(Duration(seconds: mult));
      case _Unit.minute: return d.add(Duration(minutes: mult));
      case _Unit.hour:   return d.add(Duration(hours: mult));
      case _Unit.day:    return _make(utc, d.year, d.month, d.day + mult);
      case _Unit.month:  return _make(utc, d.year, d.month + mult, 1);
      case _Unit.year:   return _make(utc, d.year + mult, 1, 1);
    }
  }
}

List<_Step> _buildSteps() {
  final steps = <_Step>[
    for (final m in [1, 5, 15, 30]) _Step(_Unit.second, m, (d) => '${_2(d.minute)}:${_2(d.second)}'),
    for (final m in [1, 5, 15, 30]) _Step(_Unit.minute, m, (d) => '${_2(d.hour)}:${_2(d.minute)}'),
    for (final m in [1, 3, 6, 12]) _Step(_Unit.hour, m, (d) => '${_2(d.hour)}:00'),
    _Step(_Unit.day, 1, (d) => '${_weekdays[d.weekday - 1]} ${d.day}'),

    _Step(_Unit.day, 3, (d) => '${_months[d.month - 1]} ${d.day}'),
    _Step(_Unit.day, 7, (d) => '${_months[d.month - 1]} ${d.day}'),

    _Step(_Unit.month, 1, (d) => _months[d.month - 1]),
    _Step(_Unit.month, 3, (d) => '${_months[d.month - 1]} ${d.year}'),
    _Step(_Unit.month, 6, (d) => '${_months[d.month - 1]} ${d.year}'),
  ];
  // Years: generate the standard "1-2-5" nice-number sequence (same scheme
  // D3/matplotlib use for axis ticks) instead of hardcoding a ceiling, so
  // century- or millennium-spanning charts still degrade sensibly.
  for (var scale = 1; scale <= 1000000; scale *= 10) {
    for (final m in [1, 2, 5]) {
      steps.add(_Step(_Unit.year, m * scale, (d) => '${d.year}'));
    }
  }
  return steps;
}

final _steps = _buildSteps();



/// Chart that renders datapoints indexed by milisecondsSinceEpoch
class SwiftTimeChart extends SwiftChart {

  /// controls which wall-clock the labels (and tick alignment) use:
  /// - `utc`: always UTC, same for every viewer everywhere.
  /// - `local`: the viewer's own browser/OS timezone — for a web chart this
  ///   is already "each admin sees their own local time" for free, no
  ///   timezone database needed, since the browser resolves it.
  /// - `both`: aligns ticks to local time, appends the UTC equivalent for
  ///   reference (does NOT independently align to UTC — that would let the
  ///   two clocks disagree about where ticks even fall).
  TimeChartDateDisplay dateDisplay;

  /// transformer for mouse moves
  ChartTransform? mouseTransform;

  //Map<int, ({String label, int time})> allTimeLabels = {};

  Map<int, int> xToTime = {};
  Map<int, String> timeTooltips = {};
  List<int> allKeysList = [];

  int? currentTime;

  HTMLDivElement container;
  HTMLDivElement canvasTip;

  Duration? interval;

  @override
  HTMLCanvasElement canvas;

  List<TimeChartSeries> series;

  //configurable display parameters
  FontFace? font;
  int fontSize = 10;

  int smallMargin;
  TimeChartDateFormatter? dateFormatter;
  String gridColor;

  bool showGrid;
  bool highlightCurrentInterval;
  bool showTip;
  bool showTimeScale;
  bool showValueScale;
  double? forcePadding;

  bool rotateTimeLabels;

  SwiftTimeChart({
    required this.container,
    required this.series,
    this.dateDisplay = TimeChartDateDisplay.local,
    this.smallMargin = 5,
    this.dateFormatter,
    this.gridColor = '#e5e5e5',
    this.showGrid = true,
    this.highlightCurrentInterval = false,
    this.showTip = true,
    this.showTimeScale = true,
    this.showValueScale = true,
    this.rotateTimeLabels = true,
    this.forcePadding
  })  : canvas = HTMLCanvasElement(),
        canvasTip = HTMLDivElement() {
    container.innerHTML = ''.toJS;
    container.className += ' swift-chart time-chart';
    container.append(canvas);
    canvas.onMouseMove.listen(handleMouseMove);
    container.onMouseLeave.listen(handleMouseLeave);
    renderMessage('rendering...');
    container.append(canvasTip);
    canvasTip.className = 'tooltip';
    canvasTip.style.display = 'none';
    SwiftChart.ensureStyles();
    initObserver();
    for (final s in series) {
      s._notify = _scheduleRender;
    }
    render();
  }

  bool _renderScheduled = false;

  void _scheduleRender() {
    if (_renderScheduled) return;
    _renderScheduled = true;
    scheduleMicrotask(() {
      _renderScheduled = false;
      render();
    });
  }

  //int valueStepsCount = 6;
  //int? currentActivePoint;


  String formatTime(DateTime date) {
    if (dateFormatter != null) {
      return dateFormatter!(date);
    }
    return '${date.year}-${forceTwoDigits(date.month)}-${forceTwoDigits(date.day)} ${forceTwoDigits(date.hour)}:${forceTwoDigits(date.minute)}';
  }

  void onPointClick(void Function(int id) callback) {
    canvas.onClick.listen((e) {
      if (currentTime != null) {
        callback(currentTime!);
      }
    });
  }

  void handleMouseLeave(MouseEvent event) {
    if (currentTime != null) {
      currentTime = null;
      renderPoints();
    }
  }

  void handleMouseMove(MouseEvent event) {
    var rect = (event.target as Element).getBoundingClientRect();
    var x = event.clientX - rect.left; //x position within the element.
    var y = event.clientY - rect.top; //y position within the element.
    final offset = 25;
    if (x > rect.width / 2) {
      canvasTip.style.left = "auto";
      canvasTip.style.right = "${rect.width - x + offset}px";
    } else {
      canvasTip.style.left = "${x + offset}px";
      canvasTip.style.right = "auto";
    }
    if (y > rect.height / 2) {
      canvasTip.style.bottom = "${rect.height - y + offset}px";
      canvasTip.style.top = "auto";
    } else {
      canvasTip.style.bottom = "auto";
      canvasTip.style.top = "${y + offset}px";
    }
    int? newCurrentTime;
    double? minDistance;
    String? label;
    if (x > leftMargin && x < leftMargin + chartWidth && y > topMargin && y < topMargin + chartHeight) {
      for (var tx in xToTime.keys) {
        var thisDistance = (x - tx).abs();
        if (minDistance == null || minDistance > thisDistance) {
          minDistance = thisDistance;
          newCurrentTime = xToTime[tx]!;
          label = timeTooltips[newCurrentTime]!;
        }
      }
    }
    if (newCurrentTime != currentTime) {
      currentTime = newCurrentTime;
      if (currentTime != null) {
        canvasTip.innerHTML = label!.toJS;
        if (showTip) {
          canvasTip.style.display = 'block';
        }
      } else {
        canvasTip.style.display = 'none';
      }
      renderPoints();
    }
  }
/*
  List<double> getValueLabels(num minValue, num maxValue, double magnitude) {
    List<double> ret = [];
    for (var i = 0; i < valueStepsCount; i++) {
      var valueStep = maxValue - (((maxValue - minValue) * i) / (valueStepsCount - 1));
      ret.add(valueStep);
    }
    return ret;
  }
*/

  String forceTwoDigits(int i) {
    return (i < 10 ? '0$i' : i.toString());
  }
  /// Generates axis tick labels for [minTime, maxTime] (epoch millis, UTC).
  ///
  Map<int, String> getTimeLabels(
      int minTime,
      int maxTime, {
        int targetTicks = 5,
      }) {
    final utc = dateDisplay == TimeChartDateDisplay.utc;

    DateTime resolve(int ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: utc);

    final rangeMs = maxTime - minTime;
    final step = _steps.firstWhere(
          (s) => rangeMs / s.approxMs <= targetTicks,
      orElse: () => _steps.last,
    );

    final ret = <int, String>{};
    var tick = step.floor(resolve(minTime), utc);
    if (tick.millisecondsSinceEpoch < minTime) tick = step.next(tick, utc);

    while (tick.millisecondsSinceEpoch <= maxTime) {
      final ms = tick.millisecondsSinceEpoch;
      var label = step.format(tick);
      if (dateDisplay == TimeChartDateDisplay.both) {
        final asUtc = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        label = '$label\n(UTC ${_2(asUtc.hour)}:${_2(asUtc.minute)})';
      }
      ret[ms] = label;
      tick = step.next(tick, utc);
    }
    return ret;
  }

  Map<int, String> getTimeLabelsOld(int minTime, int maxTime) {
    Map<int, String> ret = {};

    var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    var hour = 1000 * 60 * 60;
    var hoursDiff = ((maxTime - minTime) / hour);

    var step = 0;
    List<int> allowedMonthDays = [];
    List<int> allowedMonths = [];
    var formatter = (DateTime date) => '';
    if (hoursDiff < 30) {
      step = hour * 4;
      formatter = (DateTime date) => '${forceTwoDigits(date.hour)}:${forceTwoDigits(date.minute)}';
    } else if (hoursDiff < (24 * 8)) {
      step = hour * 24;
      formatter = (DateTime date) => '${days[date.weekday - 1]} ${date.day}';
    } else if (hoursDiff < (24 * 100)) {
      step = hour * 24 * 5;
      formatter = (DateTime date) => '${months[date.month - 1]} ${date.day}';
    } else {
      step = hour * 24;
      allowedMonthDays = [1];
      if (hoursDiff < (24 * 600)) {
        allowedMonths = [0, 2, 4, 6, 8, 10];
        formatter = (DateTime date) => months[date.month - 1];
      } else if (hoursDiff < (24 * 1000)) {
        allowedMonths = [0, 6];
        formatter = (DateTime date) => '${months[date.month - 1]} ${date.year}';
      } else {
        allowedMonths = [0];
        formatter = (DateTime date) => date.year.toString();
      }
    }
    int stepTime = (minTime / step).ceil() * step;
    while (stepTime < maxTime) {
      var stepDate = DateTime.fromMillisecondsSinceEpoch(stepTime);
      if (allowedMonthDays.isNotEmpty && (!allowedMonthDays.contains(stepDate.day))) {
        stepTime += step;
        continue;
      }
      if (allowedMonths.isNotEmpty && (!allowedMonths.contains(stepDate.month))) {
        stepTime += step;
        continue;
      }
      ret[stepTime] = formatter(stepDate);
      stepTime += step;
    }
    return ret;
  }

  static double getMagnitude(num value) {
    var magnitude = 0.001;
    while (magnitude < value) {
      magnitude *= 10;
    }
    magnitude = magnitude / 10;
    return magnitude;
  }

  int measureText(CanvasRenderingContext2D ctx, String text) {
    return (ctx.measureText(text).width).round();
  }


  int rightMargin = 0;
  int leftMargin = 0;

  int topMargin = 0;
  int timeMargin = 0;
  int textMargin = 10;

  int chartWidth = 0;
  int chartHeight = 0;

  int? minTime;
  int? maxTime;

  Map<int, String> timeLabels = {};

  //List<double> magnitudes = [];



  /*Iterable<Point> pointsForChart(int i) {
    return points.map((p) => Point(p.x, p.ys[i]));
  }*/

  @override
  void render() {
    CanvasRenderingContext2D ctx = canvas.getContext('2d') as CanvasRenderingContext2D;

    /*if (chartTypes.length < numLines) {
      chartTypes = List.filled(numLines, TimeChartTypeLine(2, 2, 'black', null));
    }*/
    minTime = null;
    maxTime = null;

    int? minDiff;
    int numBars = 0;
    for (var i = 0; i < series.length; i++) {
      series[i].minValue = 0;
      series[i].maxValue = 0;

      int? prevKey;
      for (var key in series[i].data.keys) {
        var time = key;
        minTime = (minTime == null ? time : min(minTime!, time));
        maxTime = (maxTime == null ? time : max(maxTime!, time));

        var value = series[i].data[key]!;
        series[i].minValue = min(series[i].minValue, value);
        series[i].maxValue = max(series[i].maxValue, value);
        if (prevKey != null && (minDiff == null || key - prevKey < minDiff)) {
          minDiff = key - prevKey;
        }
        prevKey = key;
      }
      if (series[i] is BarSeries) {
        numBars++;
      }
    }

    int barIdx = 0;
    interval ??= minDiff != null ? Duration(milliseconds: minDiff) : null;

    for (var i = 0; i < series.length; i++) {
      series[i].interval ??= interval;
      if (series[i] is BarSeries) {
        (series[i] as BarSeries).numBars = numBars;
        (series[i] as BarSeries).barIndex = barIdx++;
      }
    }

    if (numBars > 0) {
      //make sure bar charts will fit nicely in the chart
      minTime = (minTime! - (interval!.inMilliseconds / 2)).round();
      maxTime = (maxTime! + (interval!.inMilliseconds / 2)).round();
    }


    if (maxTime == null) {
      renderMessage('no data');
      return;
    }

    if (maxTime == minTime) {
      minTime = minTime! - 100;
      maxTime = maxTime! + 100;
    }

    leftMargin = rightMargin = smallMargin;

    //magnitudes = List.filled(numLines, 0);
    bool positionLeft = true;
    for (var i = 0; i < series.length; i++) {
      /*if (minValues[i] + minSpreads[i] > (maxValues[i] ?? 0)) {
        maxValues[i] = maxValues[i]! + minSpreads[i];
      }*/

      //valueLabels.add([]);
      //magnitudes[i] = getMagnitude(maxValues[i]!);

      series[i].scalePosition ??= positionLeft ? ChartScalePosition.left : ChartScalePosition.right;
      series[i].scale ??= AutoScaler.compute(
          position: series[i].scalePosition!,
          dataMin: series[i].minValue,
          dataMax: series[i].maxValue,
          minLines: 2, //configurable??
          maxLines: 3, //configurable??
          forceZero: true, //configurable??
          minSpan: series[i].minSpread.toDouble());

      positionLeft = !positionLeft;

      /*
      maxValues[i] = (maxValues[i] / magnitudes[i]).ceil() * magnitudes[i];
      minValues[i] = (minValues[i] / magnitudes[i]).floor() * magnitudes[i];
       */
      series[i].minValue = series[i].scale!.min;
      series[i].maxValue = series[i].scale!.max;

      if (forcePadding != null) {
        series[i].minValue = series[i].minValue - (forcePadding! * (series[i].maxValue - series[i].minValue));
        series[i].maxValue = series[i].maxValue + (forcePadding! * (series[i].maxValue - series[i].minValue));
      }

      if (showValueScale) {
        series[i].valueLabels =
            series[i].scale!.lines.reversed.toList(); //getValueLabels(minValues[i], maxValues[i], magnitudes[i]);
        for (var j = 0; j < series[i].valueLabels.length; j++) {
          if (series[i].scalePosition! == ChartScalePosition.left) {
            leftMargin =
                max(leftMargin, measureText(ctx, series[i].formatLegendValue(series[i].valueLabels[j])) + (2 * textMargin));
          } else {
            rightMargin =
                max(rightMargin, measureText(ctx, series[i].formatLegendValue(series[i].valueLabels[j])) + (2 * textMargin));
          }
        }
      }
    }

    timeMargin = 0;
    if (showTimeScale) {
      timeLabels = getTimeLabels(minTime!, maxTime!);
      if (rotateTimeLabels) {
        for (var i in timeLabels.keys) {
          timeMargin = max(timeMargin, measureText(ctx, timeLabels[i]!) + (2 * textMargin));
        }
      } else {
        //TODO: configurable font size
        timeMargin = textMargin + 14;
      }
      topMargin = smallMargin;
    } else {
      timeMargin = topMargin = smallMargin;
    }


    Set<int> allKeys = {};
    for (var i = 0; i < series.length; i++) {
      allKeys.addAll(series[i].data.keys);
    }
    allKeysList = allKeys.toList();
    allKeysList.sort();

    timeTooltips.clear();
    for (var time in allKeysList) {
      var date = DateTime.fromMillisecondsSinceEpoch(time);
      String legend = switch(dateDisplay) {
        TimeChartDateDisplay.local => '<div>${formatTime(date)}</div>',
        TimeChartDateDisplay.utc => '<div>${formatTime(date.toUtc())}</div>',
        TimeChartDateDisplay.both => '<div>${formatTime(date)}</div><div>(UTC ${formatTime(date.toUtc())})</div>'
      };

      for (var i = 0; i < series.length; i++) {
        final value = series[i].data[time];
        if (value != null) {
          legend +=
          '<div>${series[i].valueTitle}: <strong style="color:${series[i].color}">${series[i].formatValue(value)}</strong></div>';
        }
      }
      timeTooltips[time] = legend;
    }
    //RENDER POINTS
    renderPoints();
  }

  void renderPoints() {
    var ctx = startRender();
    mouseTransform = ChartTransform.forScale(
        minTime: minTime!,
        maxTime: maxTime!,
        width: (width - leftMargin - rightMargin),
        leftMargin: leftMargin,
        minValue: 0.0,
        maxValue: 1.0,
        height: 1,
        topMargin: 0);

    for (var i = 0; i < series.length; i++) {
      series[i].transform = ChartTransform.forScale(
          minTime: minTime!,
          maxTime: maxTime!,
          width: (width - leftMargin - rightMargin),
          leftMargin: leftMargin,
          minValue: series[i].minValue.toDouble(),
          maxValue: series[i].maxValue.toDouble(),
          height: (height - timeMargin - topMargin),
          topMargin: topMargin);
    }

    xToTime.clear();
    for (var time in allKeysList) {
      xToTime[mouseTransform!.apply(time, 0).x.round()] = time;
    }

    if (font != null) {
      //TODO: wait on load and reload
      //font.load().then(() => {});
      ctx.font = '${font!.style} ${font!.weight} ${fontSize}px ${font!.family}';
    } else {
      ctx.font = '${fontSize}px Arial';
    }

    ctx.lineWidth = 1;
    ctx.strokeStyle = gridColor.toJS;
    ctx.fillStyle = gridColor.toJS;

    chartWidth = width - rightMargin - leftMargin;
    chartHeight = height - timeMargin - topMargin;
    if (showGrid) {
      ctx.strokeRect(leftMargin, topMargin, chartWidth, chartHeight);
    }
    if (highlightCurrentInterval && interval != null && currentTime != null && mouseTransform != null) {
      final hX1 = mouseTransform!.apply((currentTime! - (interval!.inMilliseconds / 2)).round(), 0).x;
      final hX2 = mouseTransform!.apply((currentTime! + (interval!.inMilliseconds / 2)).round(), 0).x;
      ctx.fillRect(hX1, topMargin, hX2 - hX1, chartHeight);
    }

    ctx.save();
    ctx.textBaseline = "middle";
    for (var j = 0; j < series.length; j++) {
      var valueStepWidth = (height - timeMargin - topMargin) / (series[j].valueLabels.length - 1);
      for (var i = 0; i < series[j].valueLabels.length; i++) {
        ctx.strokeStyle = '#e5e5e5'.toJS;
        ctx.beginPath();
        ctx.moveTo(leftMargin, topMargin + (i * valueStepWidth));
        ctx.lineTo(width - rightMargin, topMargin + (i * valueStepWidth));
        ctx.stroke();
        //ctx.fillStyle;

        ctx.fillStyle = series[j].color.toJS;
        if (series[j].scalePosition == ChartScalePosition.left) {
          ctx.textAlign = "right";
          ctx.fillText(
              series[j].formatLegendValue(series[j].valueLabels[i]), leftMargin - textMargin, topMargin + (i * valueStepWidth));
        } else {
          ctx.textAlign = "left";
          ctx.fillText(series[j].formatLegendValue(series[j].valueLabels[i]), leftMargin + chartWidth + textMargin,
              topMargin + (i * valueStepWidth));
        }
      }
    }

    ctx.fillStyle = '#555'.toJS;
    ctx.strokeStyle = gridColor.toJS;

    if (rotateTimeLabels) {
      ctx.translate(leftMargin, height - timeMargin);
      ctx.rotate(-pi / 2);
      ctx.textAlign = "right";
      ctx.textBaseline = "middle";
      for (var time in timeLabels.keys) {
        ctx.save();
        ctx.translate(0, chartWidth * ((time - minTime!) / (maxTime! - minTime!)));
        ctx.beginPath();
        ctx.moveTo(0, 0);
        ctx.lineTo(chartHeight, 0);
        ctx.stroke();
        ctx.fillText(timeLabels[time]!, -textMargin, 0);
        ctx.restore();
      }
      ctx.restore();
    } else {
      ctx.textAlign = "center";
      ctx.textBaseline = "top";
      for (var time in timeLabels.keys) {
        final left = leftMargin + (chartWidth * ((time - minTime!) / (maxTime! - minTime!)));

        ctx.beginPath();
        ctx.moveTo(left, topMargin);
        ctx.lineTo(left, topMargin + chartHeight);
        ctx.stroke();

        ctx.fillText(timeLabels[time]!, left, topMargin + chartHeight + textMargin);
      }
    }

    for (var j = 0; j < series.length; j++) {
      series[j].render(this, ctx);
    }
  }
}
