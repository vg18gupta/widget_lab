import 'package:flutter_test/flutter_test.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';

void main() {
  const chartRect = (x: 2, y: 3, w: 4, h: 5);

  test('dragTarget moves by the given cells and keeps the widget inside the grid', () {
    final t = dragTarget(chartRect, 3, -10);
    expect(t.x, 5);
    expect(t.y, 0, reason: 'never above the top row');
    final far = dragTarget(chartRect, 100, 0);
    expect(far.x, gridColumns - chartRect.w);
  });

  test('resizeTarget on the right edge keeps the left edge fixed', () {
    final r = resizeTarget(chartRect, WidgetKind.chart, {ResizeSide.right}, 2, 0);
    expect(r.x, chartRect.x);
    expect(r.w, chartRect.w + 2);
  });

  test('resizeTarget on the left edge keeps the right edge fixed', () {
    final r = resizeTarget(chartRect, WidgetKind.chart, {ResizeSide.left}, 1, 0);
    expect(r.x + r.w, chartRect.x + chartRect.w);
  });

  test('resizeTarget respects each kind minimum size', () {
    final r = resizeTarget(chartRect, WidgetKind.script, {ResizeSide.right, ResizeSide.bottom}, -50, -50);
    expect(r.w, WidgetKind.script.minW);
    expect(r.h, WidgetKind.script.minH);
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
