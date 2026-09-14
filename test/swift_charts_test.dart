import 'package:test/test.dart';
import 'package:swift_charts/chart_scale.dart';

void main() {
  test('auto scaler', () {
    // Simple span with default settings:
    expect(AutoScaler.compute(dataMin: 0, dataMax: 7).toString(),
        equals('ChartScale(min: 0.0, max: 8.0, lines: [0.0, 2.0, 4.0, 6.0, 8.0])'));
    // forceZero pins the axis to 0 even when data doesn't start there:
    expect(AutoScaler.compute(dataMin: 5, dataMax: 7, forceZero: true).toString(),
        equals('ChartScale(min: 0.0, max: 8.0, lines: [0.0, 2.0, 4.0, 6.0, 8.0])'));
    // Without forceZero, bounds hug the data instead:
    expect(AutoScaler.compute(dataMin: 5, dataMax: 7, forceZero: false).toString(),
        equals('ChartScale(min: 5.0, max: 7.0, lines: [5.0, 5.5, 6.0, 6.5, 7.0])'));
    // Lower minLines, maxLines for a coarser result:
    expect(AutoScaler.compute(dataMin: 5, dataMax: 7, forceZero: false, minLines: 2, maxLines: 2).toString(),
        equals('ChartScale(min: 5.0, max: 7.5, lines: [5.0, 7.5])'));
    expect(AutoScaler.compute(dataMin: 5, dataMax: 7, forceZero: false, minLines: 2, maxLines: 3).toString(),
        equals('ChartScale(min: 5.0, max: 7.0, lines: [5.0, 6.0, 7.0])'));
    // minSpan widens a too-narrow range, pushing toward zero first:
    expect(AutoScaler.compute(dataMin: 100, dataMax: 100.001, minSpan: 10).toString(),
        equals('ChartScale(min: 90.0, max: 102.0, lines: [90.0, 92.0, 94.0, 96.0, 98.0, 100.0, 102.0])'));
    // Negative data is handled the mirror way:
    expect(AutoScaler.compute(dataMin: -90, dataMax: -40, forceZero: true).toString(),
        equals('ChartScale(min: -100.0, max: 0.0, lines: [-100.0, -80.0, -60.0, -40.0, -20.0, 0.0])'));
  });
}
