import 'dart:js_interop';
import 'dart:math';

import 'swift_charts.dart';
import 'package:web/web.dart';

typedef TimeChartValueFormatter = String Function(num value);
typedef TimeChartDateFormatter = String Function(DateTime date);

sealed class TimeChartSeries {
  String color;

  Map<int, num> data;
  ChartScale? scale;
  ChartTransform? transform;
  num minValue = 0;
  num maxValue = 0;

  Iterable<({double x, double y, bool isActive})> transformedPoints(SwiftTimeChart chart) sync* {
    for (var k in data.keys) {
      final transformed = transform!.apply(k, data[k]!.toDouble());
      yield (x: transformed.x, y: transformed.y, isActive: chart.currentTime == k);
    }
  }

  TimeChartSeries({required this.data, this.scale, this.color = '#000'});

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
  String valueTitle = 'value';

  void render(SwiftTimeChart chart, CanvasRenderingContext2D ctx);
}

class LineSeries extends TimeChartSeries {

  String? shadowColor;
  int lineWidth;
  int pointRadius;

  double smoothing;

  LineSeries(
      {required super.data,
      super.scale,
      super.color,
      this.smoothing = 0.0,
      this.lineWidth = 1,
      this.pointRadius = 2,
      this.shadowColor = '#0007'});

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
        ctx.arc(point.x, point.y, pointRadius * 2, 0, 2 * pi);
      } else {
        ctx.arc(point.x, point.y, pointRadius, 0, 2 * pi);
      }
      ctx.stroke();
      ctx.fill();
    }
  }
}

class BarSeries extends TimeChartSeries {

  String fillColor;
  int lineWidth;
  int barWidth;

  BarSeries(
      {required super.data,
      super.scale,
      super.color,
      this.lineWidth = 1,
      this.barWidth = 3,
      this.fillColor = '#0007'});

  @override
  void render(SwiftTimeChart chart, CanvasRenderingContext2D ctx) {
    ctx.strokeStyle = color.toJS;
    ctx.lineWidth = lineWidth;
    ctx.fillStyle = fillColor.toJS;
    for (var point in transformedPoints(chart)) {
      ctx.fillStyle = point.isActive ? color.toJS : fillColor.toJS;

      int w = point.isActive ? barWidth : barWidth + 2;

      if (chart.chartHeight + chart.topMargin > point.y) {
        /*ctx.roundRect(point.x - (w / 2), point.y, w, chart.chartHeight + chart.topMargin - point.y);
          CanvasRenderingContext2D.fill] or [CanvasRenderingContext2D.stroke*/

        ctx.fillRect(point.x - (w / 2), point.y, w, chart.chartHeight + chart.topMargin - point.y);
        ctx.strokeRect(point.x - (w / 2), point.y, w, chart.chartHeight + chart.topMargin - point.y);
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

/// Chart that renders datapoints indexed by milisecondsSinceEpoch
class SwiftTimeChart extends SwiftChart {
  /// transformer for mouse moves
  ChartTransform? mouseTransform;

  Map<int, (String label, int time)> allTimeLabels = {};

  int? currentTime;

  HTMLDivElement container;
  HTMLDivElement canvasTip;

  @override
  HTMLCanvasElement canvas;

  List<TimeChartSeries> series;

  //configurable display parameters
  FontFace? font;
  int fontSize = 9;

  SwiftTimeChart({
    required this.container,
    required this.series,
  })  : canvas = HTMLCanvasElement(),
        canvasTip = HTMLDivElement() {
    container.innerHTML = ''.toJS;
    container.className += ' swift-chart time-chart';
    container.append(canvas);
    canvas.onMouseMove.listen(handleMouseMove);
    container.append(canvasTip);
    renderMessage('rendering...');
    canvasTip.className = 'tooltip';
    canvasTip.style.display = 'none';
    SwiftChart.ensureStyles();
    initObserver();
    render();
  }

  //int valueStepsCount = 6;
  //int? currentActivePoint;

  TimeChartDateFormatter? dateFormatter;

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

  void handleMouseMove(MouseEvent event) {
    var rect = (event.target as Element).getBoundingClientRect();
    var x = event.clientX - rect.left; //x position within the element.
    var y = event.clientY - rect.top; //y position within the element.
    int offsetX = 60;
    int offsetY = 35;
    if (x > rect.width / 2) {
      offsetX = -60;
    }
    if (y > rect.height / 2) {
      offsetY = -35;
    }
    offsetX -= 50;
    offsetY -= 25;
    canvasTip.style.display = 'none';
    int? newCurrentTime;

    //mouseTransform.apply(time, value);

    /*for (var s in series) {
      if (time != null) {
        newCurrentTime = time;
        canvasTip.style.left = "10px";  // TODO "${points[i].x + offsetX}px";
        canvasTip.style.top = "0";//"${points[i].y + offsetY}px";
        canvasTip.innerHTML = allTimeLabels[time]!.toJS;
        if (showTip) {
          canvasTip.style.display = 'block';
        }
        break;
      }
    } */
    for (var tx in allTimeLabels.keys) {
      //TODO 1 !!!!!!!!!!!: transform?

      if ((x - tx) * (x - tx) < 100) {
        //points[i].active = true;
        //activePoint = i;
        newCurrentTime = allTimeLabels[tx]!.$2;

        canvasTip.style.left = "${tx + offsetX}px";
        canvasTip.style.top = "${y + offsetY}px";
        canvasTip.innerHTML = allTimeLabels[tx]!.$1.toJS;
        if (showTip) {
          canvasTip.style.display = 'block';
        }
      }

      /*var dx = x - points[i].x;
      var dy = 0;//y - points[i].y;
      points[i].active = false;
      if ((dx * dx) + (dy * dy) < 100) {
        points[i].active = true;
        activePoint = i;
        canvasTip.style.left = "${points[i].x + offsetX}px";
        canvasTip.style.top = "0";//"${points[i].y + offsetY}px";
        canvasTip.innerHTML = points[i].label.toJS;
        if (showTip) {
          canvasTip.style.display = 'block';
        }
      }*/
    }
    if (newCurrentTime != currentTime) {
      currentTime = newCurrentTime;
      renderPoints();
    }
  }
/*
  List<double> getValueLabels(num minValue, num maxValue, double magnitude) {
    print('SCALING');
    print(magnitude);
    print(minValue);
    print(maxValue);
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

  Map<int, String> getTimeLabels(int minTime, int maxTime) {
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

  int smallMargin = 5;

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

  bool showTimeScale = true;
  bool showValueScale = true;
  bool rotateTimeLabels = true;
  bool showGrid = true;
  bool showTip = true;

  double? forcePadding;

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

    for (var i = 0; i < series.length; i++) {
      series[i].minValue = 0;
      series[i].maxValue = 0;
      for (var key in series[i].data.keys) {
        var time = key;
        minTime = (minTime == null ? time : min(minTime!, time));
        maxTime = (maxTime == null ? time : max(maxTime!, time));

        var value = series[i].data[key]!;
        series[i].minValue = min(series[i].minValue, value);
        series[i].maxValue = max(series[i].maxValue, value);
      }
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
    for (var i = 0; i < series.length; i++) {
      /*if (minValues[i] + minSpreads[i] > (maxValues[i] ?? 0)) {
        maxValues[i] = maxValues[i]! + minSpreads[i];
      }*/

      //valueLabels.add([]);
      //magnitudes[i] = getMagnitude(maxValues[i]!);

      series[i].scale ??= AutoScaler.compute(
          dataMin: series[i].minValue,
          dataMax: series[i].maxValue,
          minLines: 2, //configurable??
          maxLines: 3, //configurable??
          forceZero: true, //configurable??
          minSpan: series[i].minSpread.toDouble());

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
          if (i.isEven) {
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
      //print(timeLabels);
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

    Set<int> allKeys = {};
    for (var i = 0; i < series.length; i++) {
      allKeys.addAll(series[i].data.keys);
    }
    var allKeysList = allKeys.toList();
    allKeysList.sort();
    for (var time in allKeysList) {
      var date = DateTime.fromMillisecondsSinceEpoch(time).toUtc();
      String legend = '<div>${formatTime(date)}</div>';
      for (var i = 0; i < series.length; i++) {
        final value = series[i].data[time];
        if (value != null) {
          legend +=
          '<div>${series[i].valueTitle}: <strong style="color:${series[i].color}">${series[i].formatValue(value)}</strong></div>';
        }
      }
      allTimeLabels[mouseTransform!.apply(time, 0).x.round()] = (legend, time);
    }
    //RENDER POINTS
    renderPoints();
  }

  void renderPoints() {
    var ctx = startRender();

    if (font != null) {
      //TODO: wait on load and reload
      //font.load().then(() => {});
      ctx.font = '${font!.style} ${font!.weight} ${fontSize}px ${font!.family}';
    } else {
      ctx.font = '${fontSize}px Arial';
    }

    ctx.lineWidth = 1;
    ctx.strokeStyle = '#e5e5e5'.toJS;
    chartWidth = width - rightMargin - leftMargin;
    chartHeight = height - timeMargin - topMargin;
    if (showGrid) {
      ctx.strokeRect(leftMargin, topMargin, chartWidth, chartHeight);
    }

    ctx.save();
    ctx.textBaseline = "middle";

    //print('RENDERING LABELS');
    //print(valueLabels);
    //print(numLines);
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
        if (j.isEven) {
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

    if (rotateTimeLabels) {
      ctx.translate(leftMargin, height - timeMargin);
      ctx.rotate(-pi / 2);
      ctx.textAlign = "right";
      ctx.textBaseline = "middle";
      for (var time in timeLabels.keys) {
        ctx.save();
        ctx.translate(0, chartWidth * ((time - minTime!) / (maxTime! - minTime!)));
        ctx.strokeStyle = '#e5e5e5'.toJS;
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
        ctx.fillText(timeLabels[time]!, leftMargin + (chartWidth * ((time - minTime!) / (maxTime! - minTime!))),
            topMargin + chartHeight + textMargin);
      }
    }

    for (var j = 0; j < series.length; j++) {
      series[j].render(this, ctx);
    }
  }
}
