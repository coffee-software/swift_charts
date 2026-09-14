import 'dart:js_interop';
import 'dart:math';
import 'dart:async';

import 'swift_charts.dart';
import 'chart_colors.dart';
import 'package:web/web.dart';

/// Single Pie Chart item.
class PieChartItem {
  String label;
  String shortLabel;

  late String color;
  bool isActive = false;
  static int maxLabelLength = 14;
  String? description;

  /// Set by the chart when this data is attached
  void Function()? _notify;

  num _weight;
  num get weight => _weight;

  set weight(num value) {
    _weight = value;
    _notify?.call();
  }

  PieChartItem(this.label, num weight, {String? color})
      : _weight = weight,
        shortLabel = (label.length > maxLabelLength) ? '${label.substring(0, maxLabelLength - 2)}..' : label {
    this.color = color ?? ColorGenerator.nextColor();
  }
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

  void _updateData() {
    data.sort((a, b) => -a.weight.compareTo(b.weight));
    totalWeight = data.map((item) => item.weight).reduce((a, b) => a + b);
    if (data.length > maxLabels) {
      var lefts = data.sublist(maxLabels - 1);
      data = data.sublist(0, maxLabels - 1);
      var leftWeight = lefts.map((i) => i.weight).reduce((a, b) => a + b);
      data.add(PieChartItem('other..', leftWeight)
        ..description = lefts.map((i) => '${(100 * i.weight / totalWeight).toStringAsFixed(2)}% ${i.label}').join('<br/>'));
    }
  }

  SwiftPieChart({required this.container, required this.data, this.legend = false})
      : canvas = HTMLCanvasElement(),
        canvasTip = HTMLDivElement() {
    container.innerHTML = ''.toJS;
    container.append(canvas);
    canvas.onMouseMove.listen(handleMouseMove);
    container.onMouseLeave.listen(handleMouseLeave);
    renderMessage('rendering...');
    container.append(canvasTip);
    container.className += ' swift-chart time-chart';
    canvasTip.className = 'tooltip';
    canvasTip.style.display = 'none';

    for (final d in data) {
      d._notify = _scheduleRender;
    }

    SwiftChart.ensureStyles();
    initObserver();
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
    final offset = 35;

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

    if (rerender) {
      render();
    }
  }

  String get legendFont => "10pt Helvetica";

  num totalWeight = 0.0;

  @override
  void render() {
    _updateData();
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

    var radius = min(centerX, centerY) * (item.isActive ? 0.88 : 0.82);
    var startingAngle = degreesToRadians((start / totalWeight) * 360 - 90.0) - (item.isActive ? 0.03 : 0);
    var arcSize = degreesToRadians((item.weight / totalWeight) * 360) + (item.isActive ? 0.06 : 0);
    var endingAngle = startingAngle + arcSize;

    ctx.beginPath();
    ctx.moveTo(centerX, centerY);
    ctx.arc(centerX, centerY, radius, startingAngle, endingAngle, false);
    ctx.closePath();

    ctx.fillStyle = item.color.toJS;
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
    var dx = (min(centerX, centerY)).floor() * 0.8 - 5;
    var dy = (height * 0.05).floor();

    ctx.textAlign = "right";
    int fontSize = min(11, (height / 25)).floor();
    ctx.font = "${item.isActive ? "bold " : ''}${fontSize}pt Helvetica";
    ctx.fillStyle = 'black'.toJS;

    ctx.fillText(item.shortLabel, dx, dy);

    ctx.restore();

    ctx.fillStyle = item.color.toJS;
    //ctx.fillRect(width - legendWidth, height - legendHeight, legendWidth, legendHeight);
    //ctx.fillText(item.label, 10, 10);
    int legendSize = 5;
    if (legend) {
      int x = width - legendWidth + 5;
      int y = height - legendHeight + (idx * 20) + 10;
      ctx.fillStyle = item.color.toJS;
      legendSize = item.isActive ? 7 : 5;
      ctx.fillRect(x - legendSize, y - legendSize, 2 * legendSize, 2 * legendSize);

      ctx.textAlign = "left";
      ctx.fillStyle = 'black'.toJS;
      ctx.font = (item.isActive ? "bold " : '') + legendFont;

      ctx.fillText(legendLabel(item), x + 10, y + 4);
    }
  }
}
