import 'dart:html';
import 'dart:math';

import 'package:swift_charts/swift_charts.dart';


class TimeChartPoint {
  int x;
  int y;
  String time;
  String value;
  bool active = false;
  TimeChartPoint(this.x, this.y, this.time, this.value);
}

typedef TimeChartValueFormatter = String Function(double value);

/**
 * Chart that renders datapoints indexed by milisecondsSinceEpoch
 */
class SwiftTimeChart extends SwiftChart<Map<int,double>> {

  Map<int,double> items = {};
  List<TimeChartPoint> points = [];
  DivElement canvasTip;

  DivElement container;
  CanvasElement canvas;

  SwiftTimeChart(this.container) :
        canvas = new CanvasElement(),
        canvasTip = new DivElement()
  {
    canvas.style.width='100%';
    canvas.style.height='200px';
    renderText('rendering...');
    canvas.onMouseMove.listen(handleMouseMove);
    container.style.position = 'relative';
    container.append(canvas);
    container.append(canvasTip);
    canvasTip.style.position = 'absolute';
    canvasTip.style.border = '1px solid gray';
    canvasTip.style.background = 'white';
    canvasTip.style.width = '100px';
    canvasTip.style.height = '50px';
    canvasTip.style.overflow = 'hidden';
    canvasTip.style.fontSize = '10px';
    canvasTip.style.padding = '5px';
    canvasTip.style.display = 'none';
  }

  int valueStepsCount = 6;
  int? currentActivePoint = null;

  TimeChartValueFormatter? valueFormatter = null;

  String formatValue(double value) {
    if (valueFormatter != null) {
      return valueFormatter!(value);
    }
    return value.toStringAsFixed(max(0, (- ((log(magnitude) / ln10) - 1)).round()));
  }

  void handleMouseMove(MouseEvent event){
    var rect = (event.target as Element).getBoundingClientRect();
    var x = event.client.x - rect.left; //x position within the element.
    var y = event.client.y - rect.top;  //y position within the element.
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
    int? activePoint = null;
    for (var i = 0; i < points.length; i++) {
      var dx = x - points[i].x;
      var dy = y - points[i].y;
      points[i].active = false;
      if ((dx * dx) + (dy * dy) < 100) {
        points[i].active = true;
        activePoint = i;
        canvasTip.style.left = (points[i].x + offsetX).toString() + "px";
        canvasTip.style.top = (points[i].y + offsetY).toString() + "px";
        canvasTip.innerHtml = points[i].time + '<br/>' + points[i].value;
        canvasTip.style.display = 'block';
      }
    }
    if (currentActivePoint != activePoint) {
      renderPoints();
    }
  }

  List<double> getValueLabels(double minValue, double maxValue) {
    List<double> ret = [];
    for (var i = 0; i < this.valueStepsCount; i++) {
      var valueStep = maxValue - (((maxValue - minValue) * i) / (this.valueStepsCount - 1));
      ret.add(valueStep);
    }
    return ret;
  }

  String forceTwoDigits(int i) {
    return (i < 10 ? '0' + i.toString() : i.toString());
  }

  Map<int, String> getTimeLabels(int minTime, int maxTime ) {

    Map<int, String> ret = {};

    var months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    var days = ['Sun','Mon','Tue','Wed','Thu','Fri','Sat'];
    var hour = 1000 * 60 *60;
    var hoursDiff = ((maxTime - minTime) / hour);

    var step = 0;
    List<int> allowedMonthDays = [];
    List<int> allowedMonths = [];
    var formatter = (DateTime date) => '';
    if (hoursDiff < 30) {
      step = hour * 4;
      formatter = (DateTime date) => this.forceTwoDigits(date.hour) + ':' + this.forceTwoDigits(date.minute);
    } else if (hoursDiff < (24 * 8)) {
      step = hour * 24;
      formatter = (DateTime date) => days[date.weekday - 1] + ' ' + date.day.toString();
    } else if (hoursDiff < (24 * 100)) {
      step = hour * 24 * 5;
      formatter = (DateTime date) => months[date.month - 1] + ' ' + date.day.toString();
    } else {
      step = hour * 24;
      allowedMonthDays = [1];
      if (hoursDiff < (24 * 600)) {
        allowedMonths = [0, 2, 4, 6, 8, 10];
        formatter = (DateTime date) => months[date.month - 1];
      } else if (hoursDiff < (24 * 1000)) {
        allowedMonths = [0, 6];
        formatter = (DateTime date) => months[date.month - 1] + ' ' + date.year.toString();
      } else {
        allowedMonths = [0];
        formatter = (DateTime date) => date.year.toString();
      }
    }
    int stepTime = (minTime / step).ceil() * step;
    while (stepTime < maxTime) {
      var stepDate = new DateTime.fromMillisecondsSinceEpoch(stepTime);
      if (allowedMonthDays.isNotEmpty && (allowedMonthDays.indexOf(stepDate.day) == -1)) {
        stepTime += step;
        continue;
      }
      if (allowedMonths.isNotEmpty && (allowedMonths.indexOf(stepDate.month) == -1)) {
        stepTime += step;
        continue;
      }
      ret[stepTime] = formatter(stepDate);
      stepTime += step;
    }
    return ret;
  }

  static double getMagnitude(double value) {
    var magnitude = 0.001;
    while (magnitude < value) {
      magnitude *= 10;
    }
    magnitude = magnitude / 100;
    return magnitude;
  }

  int measureText(CanvasRenderingContext2D ctx, String text) {
    return (ctx.measureText(text).width)!.round();
  }

  String _lineColor = 'black';
  setLineColor(String color) {
    _lineColor = color;
  }

  int _lineWidth = 2;
  setLineWidth(int width) {
    _lineWidth = width;
  }

  int _pointSize = 4;
  setPointSize(int size) {
    _pointSize = size;
  }

  int smallMargin = 5;
  int valueMargin = 0;
  int timeMargin = 0;
  int textMargin = 4;

  int? minTime = null;
  int? maxTime = null;

  List<double> valueLabels = [];
  Map<int, String> timeLabels = {};

  double magnitude = 0.0;

  render() {
    CanvasRenderingContext2D ctx = canvas.getContext('2d') as CanvasRenderingContext2D;

    minTime = null;
    maxTime = null;
    double? minValue = null;
    double? maxValue = null;
    for (var key in items.keys) {
      var time = key;
      var value = items[key]!;
      minTime = (minTime == null ? time : min(minTime!, time));
      maxTime = (maxTime == null ? time : max(maxTime!, time));
      minValue = (minValue == null ? value : min(minValue, value));
      maxValue = (maxValue == null ? value : max(maxValue, value));
    }

    if (maxTime == null || maxTime! - minTime! == 0) {
      renderText('no data');
      return;
    }

    magnitude = getMagnitude(maxValue!);
    maxValue = ((maxValue / magnitude) * magnitude).ceilToDouble();
    minValue = ((minValue! / magnitude) * magnitude).floorToDouble();

    valueLabels = getValueLabels(minValue, maxValue);

    valueMargin = 0;
    for (var i = 0; i < valueLabels.length; i++) {
      valueMargin = max(valueMargin, measureText(ctx, formatValue(valueLabels[i])) + (2 * textMargin));
    }

    timeMargin = 0;
    timeLabels = getTimeLabels(minTime!, maxTime!);
    for (var i in timeLabels.keys) {
      timeMargin = max(timeMargin, measureText(ctx, timeLabels[i]!) + (2 * textMargin));
    }

    points.clear();
    for (var key in items.keys) {
      var time = key;
      var value = items[key]!;
      var date = new DateTime.fromMillisecondsSinceEpoch(time).toUtc();
      points.add(
          TimeChartPoint(
              (((time - minTime!) / (maxTime! - minTime!)) * (width - valueMargin - smallMargin) + valueMargin).round(),
              (height - (((value - minValue) / (maxValue - minValue)) * (height - timeMargin - smallMargin)) - timeMargin).round(),
              date.year.toString() + '-' + forceTwoDigits(date.month) + '-' + forceTwoDigits(date.day) + ' '
                  + forceTwoDigits(date.hour) + ':' + forceTwoDigits(date.minute),
              'value: ' + formatValue(items[key]!)
          )
      );
    }
    //RENDER POINTS
    renderPoints();
  }

  renderPoints() {
    var ctx = startRender();
    ctx.fillStyle = 'black';
    ctx.font = '8pt Arial';

    ctx.lineWidth = 1;
    ctx.strokeStyle = '#ddd';
    var chartWidth = width - smallMargin - valueMargin;
    var chartHeight = height - timeMargin - smallMargin;
    ctx.strokeRect(valueMargin, smallMargin, chartWidth, chartHeight);

    ctx.strokeStyle = 'black';
    ctx.save();
    ctx.textAlign="right";
    ctx.textBaseline="middle";
    var valueStepWidth = (height - timeMargin - smallMargin) / (valueLabels.length - 1);
    for (var i = 0; i < valueLabels.length; i++) {
      ctx.strokeStyle = '#ccc';
      ctx.beginPath();
      ctx.moveTo(valueMargin, smallMargin + (i * valueStepWidth));
      ctx.lineTo(width - smallMargin, smallMargin + (i * valueStepWidth));
      ctx.stroke();
      ctx.fillText(formatValue(valueLabels[i]), valueMargin - textMargin, smallMargin + (i * valueStepWidth));
    }

    ctx.translate(valueMargin, height - timeMargin);
    ctx.rotate(-pi / 2);
    ctx.textAlign="right";
    ctx.textBaseline="middle";
    for (var time in timeLabels.keys) {
      ctx.save();
      ctx.translate(0, chartWidth * ((time - minTime!) / (maxTime! - minTime!)));
      ctx.strokeStyle = '#ccc';
      ctx.beginPath();
      ctx.moveTo(0, 0);
      ctx.lineTo(chartHeight, 0);
      ctx.stroke();
      ctx.fillText(timeLabels[time]!, -textMargin, 0);
      ctx.restore();
    }
    ctx.restore();

    bool first = true;
    ctx.beginPath();
    ctx.strokeStyle = _lineColor;
    ctx.fillStyle = _lineColor;
    ctx.lineWidth = _lineWidth;

    for (int i =0; i< points.length; i++) {
      if (first) {
        ctx.moveTo(points[i].x, points[i].y);
        first = false;
      } else {
        ctx.lineTo(points[i].x, points[i].y);
      }
    }
    ctx.stroke();
    for (int i =0; i< points.length; i++) {
      ctx.beginPath();
      if (points[i].active) {
        ctx.arc(points[i].x, points[i].y, _pointSize, 0, 2 * pi);
      } else {
        ctx.arc(points[i].x, points[i].y, _pointSize / 2, 0, 2 * pi);
      }
      ctx.stroke();
      ctx.fill();
    }
  }
}