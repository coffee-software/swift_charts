import 'dart:html';
import 'dart:math';

import 'package:swift_charts/swift_charts.dart';

/**
 * Chart that renders datapoints indexed by milisecondsSinceEpoch
 */
class SwiftTimeChart extends SwiftChart<Map<int,double>> {

  Map<int,double> items = {};
  CanvasElement canvas;
  SwiftTimeChart(this.canvas) {
    canvas.width = 100;
    canvas.height = 100;
    canvas.style.width ='100%';
    canvas.style.height='200px';
    renderText('rendering...');
  }

  int valueStepsCount = 6;

  List<String> getValueLabels(double minValue, double maxValue, double magnitude) {
    List<String> ret = [];
    for (var i = 0; i < this.valueStepsCount; i++) {
      var valueStep = maxValue - (((maxValue - minValue) * i) / (this.valueStepsCount - 1));
      ret.add(valueStep.toStringAsFixed(max(0, (- ((log(magnitude) / ln10) - 1)).round())));
      //ret.add(valueStep.toFixed(Math.max(0, - (Math.log10(magnitude) - 1))));
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
      formatter = (DateTime date) => months[date.month] + ' ' + date.day.toString();
    } else {
      step = hour * 24;
      allowedMonthDays = [1];
      if (hoursDiff < (24 * 600)) {
        allowedMonths = [0, 2, 4, 6, 8, 10];
        formatter = (DateTime date) => months[date.month];
      } else if (hoursDiff < (24 * 1000)) {
        allowedMonths = [0, 6];
        formatter = (DateTime date) => months[date.month] + ' ' + date.year.toString();
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

  double getMagnitude(double value) {
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

  render() {
    print('RENDER');
    var ctx = this.startRender();
    print(canvas.width!);
    print(canvas.height!);
    ctx.fillStyle = 'black';
    ctx.font = '8pt Arial';

    int? minTime = null;
    int? maxTime = null;
    double? minValue = null;
    double? maxValue = null;
    for (var key in items.keys) {
      var time = key;
      var value = items[key]!;
      minTime = (minTime == null ? time : min(minTime, time));
      maxTime = (maxTime == null ? time : max(maxTime, time));
      minValue = (minValue == null ? value : min(minValue, value));
      maxValue = (maxValue == null ? value : max(maxValue, value));
    }

    var m = getMagnitude(maxValue!);
    maxValue = ((maxValue / m) * m).ceilToDouble();
    minValue = ((minValue! / m) * m).floorToDouble();

    var valueLabels = getValueLabels(minValue, maxValue, m);
    var textMargin = 4;

    var valueMargin = 0;
    for (var i = 0; i < valueLabels.length; i++) {
      valueMargin = max(valueMargin, measureText(ctx, valueLabels[i]) + (2 * textMargin));
    }

    var timeMargin = 0;
    var timeLabels = getTimeLabels(minTime!, maxTime!);
    for (var i in timeLabels.keys) {
      timeMargin = max(timeMargin, measureText(ctx, timeLabels[i]!) + (2 * textMargin));
    }

    int smallMargin = 5;
    ctx.lineWidth = 1;
    ctx.strokeStyle = '#ddd';
    var chartWidth = canvas.width! - smallMargin - valueMargin;
    var chartHeight = canvas.height! - timeMargin - smallMargin;
    ctx.strokeRect(valueMargin, smallMargin, chartWidth, chartHeight);

    ctx.strokeStyle = 'black';
    ctx.save();
    ctx.textAlign="right";
    ctx.textBaseline="middle";
    var valueStepWidth = (canvas.height! - timeMargin - smallMargin) / (valueLabels.length - 1);
    for (var i = 0; i < valueLabels.length; i++) {
      ctx.strokeStyle = '#ccc';
      ctx.beginPath();
      ctx.moveTo(valueMargin, smallMargin + (i * valueStepWidth));
      ctx.lineTo(canvas.width! - smallMargin, smallMargin + (i * valueStepWidth));
      ctx.stroke();

      ctx.fillText(valueLabels[i], valueMargin - textMargin, smallMargin + (i * valueStepWidth));
    }

    ctx.translate(valueMargin, canvas.height! - timeMargin);
    ctx.rotate(-pi / 2);
    ctx.textAlign="right";
    ctx.textBaseline="middle";
    for (var time in timeLabels.keys) {
      ctx.save();
      ctx.translate(0, chartWidth * ((time - minTime) / (maxTime - minTime)));
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

    List<int> Xs = [];
    List<int> Ys = [];
    for (var key in items.keys) {
      var time = key;
      var value = items[key]!;
      Xs.add((((time - minTime) / (maxTime - minTime)) *
          (canvas.width! - valueMargin - smallMargin) + valueMargin).round());
      Ys.add((canvas.height! - (((value - minValue) / (maxValue - minValue)) *
          (canvas.height! - timeMargin - smallMargin)) - timeMargin).round());
    }

    for (int i =0; i< Xs.length; i++) {
      if (first) {
        ctx.moveTo(Xs[i], Ys[i]);
        first = false;
      } else {
        ctx.lineTo(Xs[i], Ys[i]);
      }
    }
    ctx.stroke();
    for (int i =0; i< Xs.length; i++) {
      ctx.beginPath();
      ctx.arc(Xs[i], Ys[i], _pointSize / 2, 0, 2 * pi);
      ctx.stroke();
      ctx.fill();
    }
  }
}