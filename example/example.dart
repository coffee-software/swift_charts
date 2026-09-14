import 'dart:math';

import 'package:web/web.dart';
import 'package:swift_charts/swift_charts.dart';

void main() {
  var random = Random();

  Map<int, num> dataPoints1 = {
    1695168000000: random.nextDouble() * 300,
    1695254400000: random.nextDouble() * 300,
    1695340800000: random.nextDouble() * 300,
    1695370000000: random.nextDouble() * 300,
    1695427200000: random.nextDouble() * 300,
    1695513600000: random.nextDouble() * 300,
    1695600000000: random.nextDouble() * 300,
    1695686400000: random.nextDouble() * 300,
  };

  Map<int, num> dataPoints2 = {
    1695168000000: random.nextDouble() * 100,
    1695254400000: random.nextDouble() * 100,
    1695340800000: random.nextDouble() * 100,
    1695513600000: random.nextDouble() * 100,
    1695600000000: random.nextDouble() * 100,
    1695686400000: random.nextDouble() * 100,
  };

  Map<int, num> dataPoints3 = {
    1695168000000: random.nextDouble() * 300,
    1695254400000: random.nextDouble() * 300,
    1695340800000: random.nextDouble() * 300,
    1695370000000: random.nextDouble() * 300,
    1695427200000: random.nextDouble() * 300,
    1695513600000: random.nextDouble() * 300,
    1695600000000: random.nextDouble() * 300,
    1695686400000: random.nextDouble() * 300,
  };

  SwiftTimeChart(container: document.getElementById('timechart1') as HTMLDivElement, series: [
    LineSeries(data: dataPoints1),
    LineSeries(data: dataPoints2),
    LineSeries(data: dataPoints3),
  ]);

  //chart with a custom scale
  var leftScale = ChartScale(position: ChartScalePosition.left, min: 0, max: 100, lines: [0, 20, 50, 100]);
  var rightScale = ChartScale.byStep(position: ChartScalePosition.right, min: 0, max: 100, step: 25);

  SwiftTimeChart(container: document.getElementById('timechart2') as HTMLDivElement, series: [
    LineSeries(scale: leftScale, data: dataPoints1, smoothing: 1.0),
    LineSeries(scale: rightScale, data: dataPoints2, smoothing: 1.0),
    BarSeries(scale: rightScale, data: dataPoints3),
  ]);

  SwiftTimeChart(container: document.getElementById('timechart3') as HTMLDivElement, series: [
    LineSeries(data: dataPoints1, color: '#f55', shadowColor: '#f554', smoothing: 1.0, lineWidth: 3, pointRadius: 5),
    LineSeries(data: dataPoints2, color: '#55f', shadowColor: '#55f4', smoothing: 1.0, lineWidth: 3, pointRadius: 5),
    LineSeries(data: dataPoints3, color: '#5f5', shadowColor: '#5f54', smoothing: 1.0, lineWidth: 3, pointRadius: 5),
  ]);

  SwiftPieChart(container: document.getElementById('piechart1') as HTMLDivElement, data: [
    PieChartItem('w 12', 12, color: 'red'),
    PieChartItem('w 24', 24, color: 'green'),
    PieChartItem('w 123', 123, color: 'blue'),
    PieChartItem('w 35', 35, color: 'orange'),
  ]);

  SwiftPieChart(container: document.getElementById('piechart2') as HTMLDivElement, data: [
    PieChartItem('20 %', 20),
    PieChartItem('25 %', 25),
    PieChartItem('15 %', 15),
    PieChartItem('30 %', 30),
    PieChartItem('10 %', 10),
  ]);
}
