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
    this.canvas.width  = this.canvas.offsetWidth;
    this.canvas.height = this.canvas.offsetHeight;
    CanvasRenderingContext2D ctx = this.canvas.getContext('2d') as CanvasRenderingContext2D;
    ctx.clearRect(0, 0, this.canvas.width!, this.canvas.height!);
    return ctx;
  }

}