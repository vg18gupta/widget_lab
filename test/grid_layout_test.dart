import 'package:flutter_test/flutter_test.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';

void main() {
  const chartRect = (x: 2, y: 3, w: 4, h: 5);

  test('liveDragRect follows the offset exactly, without snapping', () {
    final r = liveDragRect(chartRect, 1.4, 0);
    expect(r.x, closeTo(3.4, 1e-9));
    expect(r.w, 4);
  });

  test('liveDragRect stays inside the grid and above the top row', () {
    expect(liveDragRect(chartRect, 100, 0).x, gridColumns - chartRect.w);
    expect(liveDragRect(chartRect, 0, -50).y, 0);
  });

  test('liveResizeRect on the right edge keeps the left edge fixed', () {
    final r = liveResizeRect(chartRect, WidgetKind.chart, {ResizeSide.right}, 2.5, 0);
    expect(r.x, chartRect.x);
    expect(r.w, closeTo(6.5, 1e-9));
  });

  test('liveResizeRect on the left edge keeps the right edge fixed', () {
    final r = liveResizeRect(chartRect, WidgetKind.chart, {ResizeSide.left}, 1, 0);
    expect(r.x + r.w, chartRect.x + chartRect.w);
  });

  test('liveResizeRect respects each kind minimum size', () {
    final r = liveResizeRect(chartRect, WidgetKind.script,
        {ResizeSide.right, ResizeSide.bottom}, -50, -50);
    expect(r.w, WidgetKind.script.minW);
    expect(r.h, WidgetKind.script.minH);
  });

  test('snapCell does not move until the value is 60% of a cell away', () {
    expect(snapCell(3.5, 3), 3, reason: 'half a cell is not enough');
    expect(snapCell(3.59, 3), 3);
    expect(snapCell(3.6, 3), 4);
    expect(snapCell(2.45, 3), 3);
    expect(snapCell(2.3, 3), 2);
  });

  test('snapRect keeps the rectangle inside the grid', () {
    final s = snapRect((x: 11.9, y: 0, w: 4, h: 5), chartRect);
    expect(s.x + s.w, lessThanOrEqualTo(gridColumns));
  });

  test('settle closes gaps and keeps the fixed panel where it was put', () {
    final a = Panel(id: 'a', kind: WidgetKind.chart, x: 0, y: 10, w: 4, h: 5);
    final b = Panel(id: 'b', kind: WidgetKind.chart, x: 0, y: 30, w: 4, h: 5);
    settle([a, b], null);
    expect(a.y, 0);
    expect(b.y, 5);
    settle([a, b], a);
    expect(a.y, 0, reason: 'the fixed panel keeps its cell');
    expect(b.y, 5);
  });
}
