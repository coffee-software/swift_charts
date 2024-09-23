import 'dart:html';
import 'dart:math';

import 'package:swift_charts/swift_charts.dart';

class PieChartItem {
  String label;
  String shortLabel;
  double weight;
  String? color;
  bool isActive = false;
  static int maxLabelLength = 14;
  String? description = null;

  PieChartItem(this.label, this.weight, {this.color}):
    shortLabel = (label.length > maxLabelLength) ? label.substring(0, maxLabelLength - 2) + '..' : label {
  }
}
/**
 * Simple PieChart
 */
class SwiftPieChart extends SwiftChart<List<PieChartItem>> {

  List<PieChartItem> items = [];
  CanvasElement canvas;
  DivElement container;
  bool legend;
  DivElement canvasTip;

  static int maxLabels = 14;

  setData(List<PieChartItem> items) {
    items.sort((a, b) => -a.weight.compareTo(b.weight));
    totalWeight = items.map((item) => item.weight).reduce((a, b) => a + b);
    if (items.length > maxLabels) {
      var lefts = items.sublist(maxLabels - 1);
      items = items.sublist(0, maxLabels - 1);
      var leftWeight = lefts.map((i) => i.weight).reduce((a, b) => a + b);
      items.add(
          PieChartItem('other..', leftWeight)
            ..description = lefts.map((i) => (100 * i.weight / totalWeight).toStringAsFixed(2) + '% ' + i.label).join('<br/>')
      );
    }
    var c = 0;
    for (var i = 0; i < items.length; i++) {
      if (i == items.length - 1 && c == 0) {
        //make sure last color is different than first
        c = 1;
      }
      items[i].color = _colors[c];
      c++;
      if (c >= _colors.length) {
        c = 0;
      }
    }
    super.setData(items);
  }

  SwiftPieChart(this.container, { this.legend = false }) :
        canvas = new CanvasElement(),
        canvasTip = new DivElement()
  {
    container.append(canvas);
    canvas.style.width='100%';
    canvas.style.height='280px';
    canvas.onMouseMove.listen(handleMouseMove);
    canvas.onMouseLeave.listen(handleMouseLeave);
    renderText('rendering...');
    container.append(canvasTip);
    container.style.position = 'relative';

    canvasTip.style.position = 'absolute';
    canvasTip.style.border = '1px solid gray';
    canvasTip.style.background = 'white';
    canvasTip.style.minWidth = '100px';
    canvasTip.style.maxWidth = '200px';
    canvasTip.style.overflow = 'hidden';
    canvasTip.style.fontSize = '10px';
    canvasTip.style.padding = '5px';
    canvasTip.style.display = 'none';
  }

  List<String> _colors = [
    '#c472e8',
    '#ff8d72',
    '#f76ad1',
    '#ffab55',
    '#ff69b3',
    '#ffc940',
    '#ff7692',
    '#ffe640',
  ];


  void handleMouseLeave(MouseEvent event) {
    for (var item in items) {
      item.isActive = false;
    }
    canvasTip.style.display = 'none';
    render();
  }

  void handleMouseMove(MouseEvent event){
    var rect = (event.target as Element).getBoundingClientRect();
    var x = event.client.x - rect.left; //x position within the element.
    var y = event.client.y - rect.top;  //y position within the element.

    var rerender = false;
    PieChartItem? currentItem = null;
    var radius = (min(width, height) / 2) * 0.9;

    if ((x > width - legendWidth) && (y > height - legendHeight)) {

      num ly = (y - (height - legendHeight));
      for (var item in items) {
        bool newIsActive = ly > 0 && ly < 20;
        if (item.isActive != newIsActive) {
          rerender = true;
        }
        item.isActive = newIsActive;
        if (item.isActive) {
          currentItem = item;
        }
        ly -= 20;
      }
    } else if (sqrt(pow(y - centerY, 2) + pow(x - centerX, 2)) < radius) {
      var currentAngle = atan2(y - centerY, x - centerX) + (pi / 2);
      if (currentAngle < 0) {
        currentAngle = currentAngle + (2 * pi);
      }
      double startingAngle = 0;
      for (var item in items) {
        var arcSize = degreesToRadians((item.weight / totalWeight) * 360);
        bool newIsActive = (startingAngle < currentAngle &&
            (startingAngle + arcSize) > currentAngle);
        if (item.isActive != newIsActive) {
          rerender = true;
        }
        item.isActive = newIsActive;
        if (item.isActive) {
          currentItem = item;
        }
        startingAngle += arcSize;
      }
    } else {
      for (var item in items) {
        if (item.isActive) {
          rerender = true;
        }
        item.isActive = false;
      }
    }
    canvasTip.innerHtml = '<strong>' + (currentItem?.label ?? '') + '</strong><br/>' + (currentItem?.description ?? ((currentItem?.weight ?? 0) * 100 / totalWeight).toStringAsFixed(2) + '%');
    canvasTip.style.display = currentItem != null ? 'block' : 'none';

    canvasTip.style.right = (x < width / 2) ? '0' : 'auto';
    canvasTip.style.left = (x >= width / 2) ? '0' : 'auto';
    canvasTip.style.bottom = (y < height / 2) ? '0' : 'auto';
    canvasTip.style.top = (y >= height / 2) ? '0' : 'auto';

    if (rerender) {
      render();
    }
  }

  setColors(List<String> colors) {
    _colors = colors;
  }

  String get legendFont => "10pt Helvetica";

  double totalWeight = 0;
  render() {
    var ctx = this.startRender();
    legendWidth = 0;

    ctx.font = legendFont;
    items.map((item) => ctx.measureText(legendLabel(item)).width).forEach((a) {
      if (a! > legendWidth) {
        legendWidth = a.ceil();
      }
    });
    legendWidth += 30;

    double start = 0;
    for (var i = 0; i < items.length; i++) {
      if (!items[i].isActive) {
        drawSegment(ctx, i, items[i], start);
      }
      start += items[i].weight;
    }
    //draw active items over inactive
    start = 0;
    for (var i = 0; i < items.length; i++) {
      if (items[i].isActive) {
        drawSegment(ctx, i, items[i], start);
      }
      start += items[i].weight;
    }
  }

  int get centerX => legend ? ((width - legendWidth) / 2).floor() : (width / 2).floor();
  int get centerY => (height / 2).floor();

  int get legendHeight => 20 * items.length;
  int legendWidth = 0;


  drawSegment(CanvasRenderingContext2D ctx, int idx, PieChartItem item, double start) {
    ctx.save();

    var radius = (min(width, height) / 2) * (item.isActive ? 0.88 : 0.82);
    var startingAngle = degreesToRadians((start / totalWeight) * 360 - 90.0) - (item.isActive ? 0.03 : 0);
    var arcSize = degreesToRadians((item.weight / totalWeight) * 360) + (item.isActive ? 0.06 : 0);
    var endingAngle = startingAngle + arcSize;

    ctx.beginPath();
    ctx.moveTo(centerX, centerY);
    ctx.arc(centerX, centerY, radius,
    startingAngle, endingAngle, false);
    ctx.closePath();

    ctx.fillStyle = item.color;
    ctx.fill();
    ctx.restore();

    this.drawSegmentLabel(ctx, idx, item, start);
  }

  double degreesToRadians(double degrees) {
    return (degrees * pi) / 180;
  }

  String legendLabel(PieChartItem item) {
    return (item.weight * 100 / totalWeight).round().toString() + '% ' + item.shortLabel;
  }

  drawSegmentLabel(CanvasRenderingContext2D ctx, int idx, PieChartItem item, double start) {
    ctx.save();
    var angle = this.degreesToRadians((start / totalWeight) * 360 - 90);

    ctx.translate(centerX, centerY);
    ctx.rotate(angle);
    var dx = (min(width, height) * 0.5).floor() * 0.8 - 5;
    var dy = (height * 0.05).floor();

    ctx.textAlign = "right";
    int fontSize = min(11, (height / 25)).floor();
    ctx.font = (item.isActive ? "bold " : '') + fontSize.toString() + "pt Helvetica";

    ctx.fillText(item.shortLabel, dx, dy);

    ctx.restore();

    ctx.fillStyle = item.color;
    //ctx.fillRect(width - legendWidth, height - legendHeight, legendWidth, legendHeight);
    //ctx.fillText(item.label, 10, 10);
    int legendSize = 5;
    if (legend) {

      int x = width - legendWidth + 5;
      int y = height - legendHeight + (idx * 20) + 10;
      ctx.fillStyle = item.color;
      legendSize = item.isActive ? 7 : 5;
      ctx.fillRect(x - legendSize, y - legendSize, 2 * legendSize, 2 * legendSize);

      ctx.textAlign = "left";
      ctx.fillStyle = 'black';
      ctx.font = (item.isActive ? "bold " : '') + legendFont;

      ctx.fillText(legendLabel(item), x + 10, y + 4);
    }
  }
}