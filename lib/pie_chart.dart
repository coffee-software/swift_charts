import 'dart:js_interop';
import 'dart:math';

import 'swift_charts.dart';
import 'package:web/web.dart';

class PieChartItem {
  String label;
  String shortLabel;
  double weight;
  String? color;
  bool isActive = false;
  static int maxLabelLength = 14;
  String? description;

  PieChartItem(this.label, this.weight, {this.color})
      : shortLabel = (label.length > maxLabelLength) ? '${label.substring(0, maxLabelLength - 2)}..' : label;
}

/// Simple PieChart
class SwiftPieChart extends SwiftChart {
  List<PieChartItem> data;

  @override
  HTMLCanvasElement canvas;
  HTMLDivElement container;
  bool legend;
  HTMLDivElement canvasTip;

  static int maxLabels = 14;

  void updateData() {
    data.sort((a, b) => -a.weight.compareTo(b.weight));
    totalWeight = data.map((item) => item.weight).reduce((a, b) => a + b);
    if (data.length > maxLabels) {
      var lefts = data.sublist(maxLabels - 1);
      data = data.sublist(0, maxLabels - 1);
      var leftWeight = lefts.map((i) => i.weight).reduce((a, b) => a + b);
      data.add(PieChartItem('other..', leftWeight)
        ..description = lefts.map((i) => '${(100 * i.weight / totalWeight).toStringAsFixed(2)}% ${i.label}').join('<br/>'));
    }
    var c = 0;
    for (var i = 0; i < data.length; i++) {
      if (i == data.length - 1 && c == 0) {
        //make sure last color is different than first
        c = 1;
      }
      data[i].color = _colors[c];
      c++;
      if (c >= _colors.length) {
        c = 0;
      }
    }
  }

  SwiftPieChart({required this.container, required this.data, this.legend = false})
      : canvas = HTMLCanvasElement(),
        canvasTip = HTMLDivElement() {
    container.innerHTML = ''.toJS;
    container.append(canvas);
    canvas.onMouseMove.listen(handleMouseMove);
    canvas.onMouseLeave.listen(handleMouseLeave);
    renderMessage('rendering...');
    container.append(canvasTip);
    container.className += ' swift-chart time-chart';
    canvasTip.className = 'tooltip';
    canvasTip.style.display = 'none';
    SwiftChart.ensureStyles();
    initObserver();
    render();
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
    for (var item in data) {
      item.isActive = false;
    }
    canvasTip.style.display = 'none';
    render();
  }

  void handleMouseMove(MouseEvent event) {
    var rect = (event.target as Element).getBoundingClientRect();
    var x = event.clientX - rect.left; //x position within the element.
    var y = event.clientY - rect.top; //y position within the element.

    var rerender = false;
    PieChartItem? currentItem;
    var radius = (min(width, height) / 2) * 0.9;

    if ((x > width - legendWidth) && (y > height - legendHeight)) {
      num ly = (y - (height - legendHeight));
      for (var item in data) {
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
      for (var item in data) {
        var arcSize = degreesToRadians((item.weight / totalWeight) * 360);
        bool newIsActive = (startingAngle < currentAngle && (startingAngle + arcSize) > currentAngle);
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
      for (var item in data) {
        if (item.isActive) {
          rerender = true;
        }
        item.isActive = false;
      }
    }
    canvasTip.innerHTML =
        ('<strong>${currentItem?.label ?? ''}</strong><br/>${currentItem?.description ?? '${((currentItem?.weight ?? 0) * 100 / totalWeight).toStringAsFixed(2)}%'}')
            .toJS;
    canvasTip.style.display = currentItem != null ? 'block' : 'none';

    canvasTip.style.right = (x < width / 2) ? '0' : 'auto';
    canvasTip.style.left = (x >= width / 2) ? '0' : 'auto';
    canvasTip.style.bottom = (y < height / 2) ? '0' : 'auto';
    canvasTip.style.top = (y >= height / 2) ? '0' : 'auto';

    if (rerender) {
      render();
    }
  }

  void setColors(List<String> colors) {
    _colors = colors;
  }

  String get legendFont => "10pt Helvetica";

  double totalWeight = 0;
  @override
  void render() {
    updateData();
    var ctx = startRender();
    legendWidth = 0;

    ctx.font = legendFont;
    data.map((item) => ctx.measureText(legendLabel(item)).width).forEach((a) {
      if (a > legendWidth) {
        legendWidth = a.ceil();
      }
    });
    legendWidth += 30;

    double start = 0;
    for (var i = 0; i < data.length; i++) {
      if (!data[i].isActive) {
        drawSegment(ctx, i, data[i], start);
      }
      start += data[i].weight;
    }
    //draw active items over inactive
    start = 0;
    for (var i = 0; i < data.length; i++) {
      if (data[i].isActive) {
        drawSegment(ctx, i, data[i], start);
      }
      start += data[i].weight;
    }
  }

  int get centerX => legend ? ((width - legendWidth) / 2).floor() : (width / 2).floor();
  int get centerY => (height / 2).floor();

  int get legendHeight => 20 * data.length;
  int legendWidth = 0;

  void drawSegment(CanvasRenderingContext2D ctx, int idx, PieChartItem item, double start) {
    ctx.save();

    var radius = (min(width, height) / 2) * (item.isActive ? 0.88 : 0.82);
    var startingAngle = degreesToRadians((start / totalWeight) * 360 - 90.0) - (item.isActive ? 0.03 : 0);
    var arcSize = degreesToRadians((item.weight / totalWeight) * 360) + (item.isActive ? 0.06 : 0);
    var endingAngle = startingAngle + arcSize;

    ctx.beginPath();
    ctx.moveTo(centerX, centerY);
    ctx.arc(centerX, centerY, radius, startingAngle, endingAngle, false);
    ctx.closePath();

    ctx.fillStyle = (item.color ?? '').toJS;
    ctx.fill();
    ctx.restore();

    drawSegmentLabel(ctx, idx, item, start);
  }

  double degreesToRadians(double degrees) {
    return (degrees * pi) / 180;
  }

  String legendLabel(PieChartItem item) {
    return '${(item.weight * 100 / totalWeight).round()}% ${item.shortLabel}';
  }

  void drawSegmentLabel(CanvasRenderingContext2D ctx, int idx, PieChartItem item, double start) {
    ctx.save();
    var angle = degreesToRadians((start / totalWeight) * 360 - 90);

    ctx.translate(centerX, centerY);
    ctx.rotate(angle);
    var dx = (min(width, height) * 0.5).floor() * 0.8 - 5;
    var dy = (height * 0.05).floor();

    ctx.textAlign = "right";
    int fontSize = min(11, (height / 25)).floor();
    ctx.font = "${item.isActive ? "bold " : ''}${fontSize}pt Helvetica";
    ctx.fillStyle = 'black'.toJS;

    ctx.fillText(item.shortLabel, dx, dy);

    ctx.restore();

    ctx.fillStyle = (item.color ?? '').toJS;
    //ctx.fillRect(width - legendWidth, height - legendHeight, legendWidth, legendHeight);
    //ctx.fillText(item.label, 10, 10);
    int legendSize = 5;
    if (legend) {
      int x = width - legendWidth + 5;
      int y = height - legendHeight + (idx * 20) + 10;
      ctx.fillStyle = (item.color ?? '').toJS;
      legendSize = item.isActive ? 7 : 5;
      ctx.fillRect(x - legendSize, y - legendSize, 2 * legendSize, 2 * legendSize);

      ctx.textAlign = "left";
      ctx.fillStyle = 'black'.toJS;
      ctx.font = (item.isActive ? "bold " : '') + legendFont;

      ctx.fillText(legendLabel(item), x + 10, y + 4);
    }
  }
}
