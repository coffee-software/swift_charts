import 'dart:js_interop';

import 'package:web/web.dart';

export 'time_chart.dart';
export 'pie_chart.dart';
export 'chart_scale.dart';

class _ChartStyles {
  static bool _injected = false;
  static const _css = '''
:where(.swift-chart) {  
  position: relative;
}
:where(.swift-chart canvas) {
  width: 100%;
  height: 100%;
  display: block;
}
:where(.swift-chart .tooltip) {
  position: absolute;
  background: white;
  border: 1px solid #ccc;
  min-width: 50px;
  min-height: 50px;
  border-radius: 4px;
  padding: 8px 12px;
  font: 13px sans-serif;
  box-shadow: 0 2px 8px rgba(0,0,0,.15);
}
''';

  static void ensureInjected() {
    if (_injected) {
      return;
    }
    final style = document.createElement('style') as HTMLStyleElement;
    style.textContent = _css;
    document.head!.insertBefore(style, document.head!.firstChild);
    _injected = true;
  }
}

abstract class SwiftChart {
  abstract HTMLCanvasElement canvas;

  void render();

  int get width => canvas.width;
  int get height => canvas.height;

  ResizeObserver? _resizeObserver;

  static void ensureStyles() {
    _ChartStyles.ensureInjected();
  }

  void initObserver() {
    _resizeObserver = ResizeObserver(((JSArray entries, ResizeObserver observer) {
      render();
    }).toJS);
    _resizeObserver!.observe(canvas);
  }

  /// in case ResizeObserver wont get GCed this forces cleanup
  void dispose() {
    _resizeObserver?.disconnect();
  }

  void renderMessage(String text) {
    var ctx = startRender();
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, width / 2, height / 2);
  }

  CanvasRenderingContext2D startRender() {
    CanvasRenderingContext2D ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
    final rect = canvas.getBoundingClientRect();
    if (rect.width != 0 && rect.height != 0) {
      canvas.width = (rect.width * window.devicePixelRatio).round();
      canvas.height = (rect.height * window.devicePixelRatio).round();
    }
    ctx.clearRect(0, 0, width, height);
    return ctx;
  }
}
