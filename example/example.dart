import 'dart:js_interop';

import 'package:web/web.dart';
import 'package:swift_charts/swift_charts.dart';

void main() {

  var dataPoints = {
    1695168000000: 105.5,
    1695254400000: 69.3,
    1695340800000: 50.5,
    1695370000000: 44.2,
    1695427200000: 42.0,
    1695513600000: 17.45,
    1695600000000: 82.4,
    1695686400000: 99.6,
  };

  List<SwiftChart> charts = [];

  charts.add(
      SwiftTimeChart(document.getElementById('timechart1') as HTMLDivElement)
        ..setData(dataPoints)
  );

  charts.add(
      SwiftTimeChart(document.getElementById('timechart2') as HTMLDivElement)
        ..setLineColor('blue')
        ..setLineWidth(3)
        ..setPointSize(8)
        ..setData(dataPoints.map((key, value) => MapEntry(key * 5, 5 * value)))
  );

  charts.add(
      SwiftTimeChart(document.getElementById('timechart3') as HTMLDivElement)
        ..setLineColor('red')
        ..setData(dataPoints.map((key, value) => MapEntry((key / 5).round(), 2 * value)))
  );

  charts.add(
      SwiftPieChart(document.getElementById('piechart1') as HTMLDivElement)
        ..setData([
          PieChartItem('w 12', 12, color: 'red'),
          PieChartItem('w 24', 24, color: 'green'),
          PieChartItem('w 123', 123, color: 'blue'),
          PieChartItem('w 35', 35, color: 'orange'),
        ])
  );

  charts.add(
      SwiftPieChart(document.getElementById('piechart2') as HTMLDivElement)
        ..setData([
          PieChartItem('20 %', 20),
          PieChartItem('25 %', 25),
          PieChartItem('15 %', 15),
          PieChartItem('30 %', 30),
          PieChartItem('10 %', 10),
        ])
  );

  for (var element in charts) {element.render();}

  window.addEventListener('resize', () {
    for (var element in charts) {element.render();}
  }.toJS);
}