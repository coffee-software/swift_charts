import 'dart:math';

import 'package:web/web.dart';
import 'package:swift_charts/swift_charts.dart';

void main() {
  var random = Random();

  //TODO
  int millisAt(int y, int m, int d) {
    // Poland 2026: CET (UTC+1) until Mar 29 01:00 UTC, then CEST (UTC+2)
    // until Oct 25 01:00 UTC, then back to CET.
    final utcMidnight = DateTime.utc(y, m, d);
    final isCEST = utcMidnight.isAfter(DateTime.utc(2026, 3, 29, 1)) &&
        utcMidnight.isBefore(DateTime.utc(2026, 10, 25, 1));
    final offsetHours = isCEST ? 2 : 1;
    return utcMidnight.subtract(Duration(hours: offsetHours)).millisecondsSinceEpoch;
  }

  Map<int, num> generateRandomDataPoints(int length, {num min = 0.0, num max= 100.0}) {
    Map<int, num> ret = {};
    var startDate = DateTime.parse('2026-10-24');
    for (int i=0; i<length; i++) {
      ret[startDate.millisecondsSinceEpoch] = (random.nextDouble() * (max - min)) + min;
      startDate = startDate.add(Duration(days:1));
    }
    return ret;
  }

  Map<int, num> smallSet = generateRandomDataPoints(4);


  Map<int, num> dataPoints1 = generateRandomDataPoints(8);
  Map<int, num> dataPoints2 = generateRandomDataPoints(8);
  Map<int, num> dataPoints3 = generateRandomDataPoints(8);

  var timeChart = SwiftTimeChart(
      container: document.getElementById('timechart') as HTMLDivElement,
      series: [
        LineSeries(
          data: dataPoints1,
          smoothing: 1.0
        ),
        LineSeries(
            data: dataPoints2,
            smoothing: 1.0
        ),
        LineSeries(
            data: dataPoints3,
            smoothing: 1.0
        ),
      ]
  );
  document.getElementById('timechartReload')!.onClick.listen((e){
    timeChart.series.forEach((series){
      series.data = generateRandomDataPoints(8);
    });
  });

  var barChart =SwiftTimeChart(container: document.getElementById('barchart') as HTMLDivElement, series: [
    BarSeries(data: dataPoints1),
    BarSeries(data: dataPoints2),
    BarSeries(data: dataPoints3),
  ]);
  document.getElementById('barchartReload')!.onClick.listen((e){
    barChart.series.forEach((series){
      series.data = generateRandomDataPoints(8);
    });
  });

  List<SwiftPieChart> pieCharts = [
    SwiftPieChart(
        container: document.getElementById('piechart1') as HTMLDivElement,
        legend: true,
        data: [
          PieChartItem('red', 12, color: 'red'),
          PieChartItem('green', 24, color: 'green'),
          PieChartItem('blue', 123, color: 'blue'),
          PieChartItem('orange', 35, color: 'orange'),
        ]
    ),

    SwiftPieChart(
        container: document.getElementById('piechart2') as HTMLDivElement,
        data: [
          PieChartItem('item 1', 20),
          PieChartItem('item 2', 25),
          PieChartItem('item 3', 15),
          PieChartItem('item 4', 30),
          PieChartItem('item 5', 10),
        ]
    ),

    SwiftPieChart(
        container: document.getElementById('piechart3') as HTMLDivElement,
        legend: true,
        data: [
          PieChartItem('foo', 20),
          PieChartItem('bar', 30),
          PieChartItem('faz', 15),
          PieChartItem('baz', 15),
          PieChartItem('boo', 10),
          PieChartItem('foo', 10),
        ]
    )
  ];
  document.getElementById('piechartsReload')!.onClick.listen((e){
    pieCharts.forEach((pieChart) {
      pieChart.data.forEach((data){
        data.weight = random.nextInt(20) + 1;
      });
    });
  });

  SwiftTimeChart(
      container: document.getElementById('tzchart1') as HTMLDivElement,
      series: [LineSeries(data: smallSet)],
      dateDisplay: TimeChartDateDisplay.local
  );
  SwiftTimeChart(
      container: document.getElementById('tzchart2') as HTMLDivElement,
      series: [LineSeries(data: smallSet)],
      dateDisplay: TimeChartDateDisplay.utc
  );
  SwiftTimeChart(container: document.getElementById('tzchart3') as HTMLDivElement,
      series: [LineSeries(data: smallSet)],
      dateDisplay: TimeChartDateDisplay.both
  );



  //chart with a custom scale
  var leftScale = ChartScale(position: ChartScalePosition.left, min: 0, max: 400, lines: [0, 200, 400]);
  var rightScale = ChartScale.byStep(position: ChartScalePosition.right, min: 0, max: 100, step: 25);

  SwiftTimeChart(container: document.getElementById('timechart2') as HTMLDivElement, series: [
    LineSeries(scale: leftScale, data: dataPoints1, smoothing: 1.0),
    LineSeries(scale: rightScale, data: dataPoints2, smoothing: 1.0),
    BarSeries(scale: rightScale, data: dataPoints3),
    BarSeries(scale: rightScale, data: generateRandomDataPoints(8)),
  ]);

  SwiftTimeChart(
      container: document.getElementById('timechart3') as HTMLDivElement,
      series: [
        LineSeries(data: dataPoints1, color: '#f55', shadowColor: '#f554', smoothing: 1.0, lineWidth: 3, pointRadius: 5),
        LineSeries(data: dataPoints2, color: '#55f', shadowColor: '#55f4', smoothing: 1.0, lineWidth: 3, pointRadius: 5),
        LineSeries(data: dataPoints3, color: '#5f5', shadowColor: '#5f54', smoothing: 1.0, lineWidth: 3, pointRadius: 5),
      ],
      fontSize: 13,
      rotateTimeLabels: false
  );

}
