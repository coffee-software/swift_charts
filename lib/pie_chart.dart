import 'dart:html';
import 'dart:math';

import 'package:swift_charts/swift_charts.dart';

class PieChartItem {
  String label;
  double weight;
  String? color;
  PieChartItem(this.label, this.weight, {this.color});
}
/**
 * Simple PieChart
 */
class SwiftPieChart extends SwiftChart<List<PieChartItem>> {

  List<PieChartItem> items = [];
  CanvasElement canvas;
  SwiftPieChart(this.canvas) {
    canvas.width = 100;
    canvas.height = 100;
    canvas.style.width ='100%';
    canvas.style.height='200px';
    renderText('rendering...');
  }

  List<String> _colors = [
    'rgb(202, 175, 123)',
    'rgb(208, 136, 113)',
    'rgb(180, 135, 113)',
    'rgb(216, 181, 105)',
    'rgb(198, 116, 103)',
    'rgb(206, 161, 105)',
    'rgb(220, 175, 143)'
  ];

  setColors(List<String> colors) {
    _colors = colors;
  }

  render() {
    var ctx = this.startRender();
    double start = 0;
    double total = 0;
    var c = 0;
    for (var i = 0; i < items.length; i++) {
      total += items[i].weight;
    }
    for (var i = 0; i < items.length; i++) {
      if (i == items.length - 1 && c == 0) {
        //make sure last color is different than first
        c = 1;
      }
      if (items[i].color == null) {
        items[i].color = _colors[c];
      }
      drawSegment(ctx, items[i], start, total);
      c++;
      if (c >= _colors.length) {
        c = 0;
      }
      start += items[i].weight;
    }
  }

  drawSegment(CanvasRenderingContext2D ctx, PieChartItem item, double start, double total) {
    print('DRAW SEGMENT');
    ctx.save();
    var centerX = (canvas.width! / 2).floor();
    var centerY = (canvas.height! / 2).floor();
    var radius = (min(canvas.width!, canvas.height!) / 2) * 0.8;

    var startingAngle = degreesToRadians((start / total) * 360 - 90.0);
    var arcSize = degreesToRadians((item.weight / total) * 360);
    var endingAngle = startingAngle + arcSize;

    ctx.beginPath();
    ctx.moveTo(centerX, centerY);
    ctx.arc(centerX, centerY, radius,
    startingAngle, endingAngle, false);
    ctx.closePath();

    print([centerX, centerY, radius, startingAngle, endingAngle, false]);

    ctx.fillStyle = item.color;
    ctx.fill();
    ctx.restore();

    this.drawSegmentLabel(ctx, item, start, total);
  }

  double degreesToRadians(double degrees) {
    return (degrees * pi) / 180;
  }

  drawSegmentLabel(CanvasRenderingContext2D ctx, PieChartItem item, double start, double total) {
    ctx.save();
    var x = (canvas.width! / 2).floor();
    var y = (canvas.height! / 2).floor();
    var angle = this.degreesToRadians((start / total) * 360 - 90);

    ctx.translate(x, y);
    ctx.rotate(angle);
    var dx = (min(canvas.width!, canvas.height!) * 0.5).floor() * 0.8 - 10;
    var dy = (canvas.height! * 0.05).floor();

    ctx.textAlign = "right";
    int fontSize = (canvas.height! / 25).floor();
    ctx.font = fontSize.toString() + "pt Helvetica";

    ctx.fillText(item.label, dx, dy);

    ctx.restore();
  }
}