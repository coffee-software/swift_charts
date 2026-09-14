
abstract class ColorGenerator {
  static const double _goldenAngle = 137.50776; // degrees; 360 * (1 - 1/phi)

  static int globalIndex = 0;

  /// Deterministic, index-stable color: colorForIndex(3) is always the same
  /// color, regardless of how many series exist total. Good default when
  /// series can be added/removed dynamically, or the total count isn't known.
  static String colorForIndex(int index, {double saturation = 0.55, double lightness = 0.55}) {
    final hue = (index * _goldenAngle) % 360;
    return _hslToHex(hue, saturation, lightness);
  }

  /// Evenly divides the hue wheel into exactly [n] slices — mathematically
  /// the most uniform spacing possible, but ONLY for that exact n. Adding a
  /// color later means recomputing the whole palette, and every existing
  /// series' color shifts. Good default when the count is fixed and known
  /// up front (e.g. a static dashboard with a declared set of metrics).
  static List<String> generatePalette(int n, {double saturation = 0.55, double lightness = 0.55}) =>
      [for (var i = 0; i < n; i++) _hslToHex(i * 360 / n, saturation, lightness)];

  ///
  static String nextColor() {
    return colorForIndex(globalIndex++);
  }

  static String _hslToHex(double h, double s, double l) {
    final c = (1 - (2 * l - 1).abs()) * s;
    final x = c * (1 - ((h / 60) % 2 - 1).abs());
    final m = l - c / 2;
    double r1 = 0, g1 = 0, b1 = 0;
    if (h < 60)       { r1 = c; g1 = x; b1 = 0; }
    else if (h < 120) { r1 = x; g1 = c; b1 = 0; }
    else if (h < 180) { r1 = 0; g1 = c; b1 = x; }
    else if (h < 240) { r1 = 0; g1 = x; b1 = c; }
    else if (h < 300) { r1 = x; g1 = 0; b1 = c; }
    else              { r1 = c; g1 = 0; b1 = x; }

    int toHex(double v) => ((v + m) * 255).round().clamp(0, 255);
    final r = toHex(r1), g = toHex(g1), b = toHex(b1);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
        '${g.toRadixString(16).padLeft(2, '0')}'
        '${b.toRadixString(16).padLeft(2, '0')}';
  }

}
