import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradl_widget_lab/market/market_store.dart';
import 'package:tradl_widget_lab/models/panel.dart';
import 'package:tradl_widget_lab/state/workspace.dart';

void main() {
  late Workspace ws;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ws = Workspace(MarketStore());
    await ws.load();
  });

  // Default layout: 'default-chart' is at x:0 y:0 w:6 h:7.
  final chart = (Workspace w) => w.panels.firstWhere((p) => p.id == 'default-chart');

  test('load produces the default layout and marks the workspace loaded', () {
    expect(ws.loaded, isTrue);
    expect(ws.panels.length, 3);
  });

  test('small pointer movements accumulate instead of rounding to zero', () {
    const cellW = 60.0;
    final p = chart(ws);
    ws.beginGesture(p);
    ws.dragBy(p, 20, 0, cellW); // 0.33 cells: no move yet
    expect(p.x, 0);
    ws.dragBy(p, 40, 0, cellW); // total 40px = 0.67 cells: rounds to 1
    expect(p.x, 1);
    ws.endGesture();
  });

  test('a whole drag is one undo step', () {
    const cellW = 60.0;
    final p = chart(ws);
    ws.beginGesture(p);
    for (var px = 0.0; px <= 180; px += 6) {
      ws.dragBy(p, px, 0, cellW);
    }
    ws.endGesture();
    expect(p.x, 3);
    ws.undo();
    expect(chart(ws).x, 0, reason: 'one undo should revert the entire drag');
  });

  test('dragging stops at the right edge of the 12-column grid', () {
    const cellW = 60.0;
    final p = chart(ws); // w = 6
    ws.beginGesture(p);
    ws.dragBy(p, 5000, 0, cellW);
    expect(p.x, 12 - p.w);
    expect(p.x + p.w, lessThanOrEqualTo(12));
    ws.endGesture();
  });

  test('dragging never goes above the top row', () {
    const cellW = 60.0;
    final p = chart(ws);
    ws.beginGesture(p);
    ws.dragBy(p, 0, -500, cellW);
    expect(p.y, 0);
    ws.endGesture();
  });

  test('right-edge resize accumulates and respects grid and minimum size', () {
    const cellW = 60.0;
    final p = chart(ws); // kind chart min 3x3
    final w0 = p.w;
    ws.beginGesture(p);
    ws.resizeBy(p, {ResizeSide.right}, 30, 0, cellW); // 0.5 cells rounds to 1
    expect(p.w, w0 + 1);
    ws.resizeBy(p, {ResizeSide.right}, 5000, 0, cellW);
    expect(p.w, 12 - p.x);
    ws.resizeBy(p, {ResizeSide.right, ResizeSide.bottom}, -5000, -5000, cellW);
    expect(p.w, WidgetKind.chart.minW);
    expect(p.h, WidgetKind.chart.minH);
    ws.endGesture();
  });

  test('a gesture on one panel ignores updates for another', () {
    const cellW = 60.0;
    final p = chart(ws);
    final other = ws.panels.firstWhere((e) => e.id == 'default-table');
    final before = other.x;
    ws.beginGesture(p);
    ws.dragBy(other, 300, 0, cellW);
    expect(other.x, before, reason: 'the table was not the active gesture panel');
    ws.endGesture();
  });
}
