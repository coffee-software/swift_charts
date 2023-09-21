import 'dart:html';

export 'time_chart.dart';
export 'pie_chart.dart';


abstract class SwiftChart<T> {

  abstract CanvasElement canvas;
  abstract T items;

  setData(T items) {
    this.items = items;
  }

  render();

  renderText(String text) {
    var ctx = startRender();
    ctx.textAlign = "center";
    ctx.textBaseline = "middle";
    ctx.fillText(text, canvas.width! / 2, canvas.height! / 2);
  }

  CanvasRenderingContext2D startRender() {
    canvas.width  = canvas.offsetWidth;
    canvas.height = canvas.offsetHeight;
    CanvasRenderingContext2D ctx = canvas.getContext('2d') as CanvasRenderingContext2D;
    ctx.clearRect(0, 0, canvas.width!, canvas.height!);
    return ctx;
  }

}