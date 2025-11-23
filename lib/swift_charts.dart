import 'package:web/web.dart';

export 'time_chart.dart';
export 'pie_chart.dart';

abstract class SwiftChart<T> {
  abstract HTMLCanvasElement canvas;
  abstract T items;

  void setData(T items) {
    this.items = items;
  }

  void render();

  int get width => canvas.clientWidth;
  int get height => canvas.clientHeight;

  void renderText(String text) {
    var ctx = startRender();
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, width / 2, height / 2);
  }

  CanvasRenderingContext2D startRender() {
    CanvasRenderingContext2D ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
    ctx.canvas.width = width;
    ctx.canvas.height = height;
    ctx.clearRect(0, 0, width, height);
    return ctx;
  }
}
