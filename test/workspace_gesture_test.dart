import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/controller/app_controllers.dart';
import 'package:widget_lab/data/layout_repository.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/market_store.dart';
import 'support/cells.dart';

/// An in-memory repository, so the workspace tests don't touch storage.
class _MemoryRepository implements LayoutRepository {
  String? text;
  @override
  Future<String?> read() async => text;
  @override
  Future<void> write(String t) async => text = t;
}

void main() {
  late AppControllers ws;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ws = AppControllers(market: MarketStore(), repository: _MemoryRepository());
    await ws.layout.load();
  });

  // Default layout: 'default-chart' is at x:0 y:0 w:4 h:7.
  Panel chart(AppControllers w) => w.store.panels.firstWhere((p) => p.id == 'default-chart');

  test('load produces the default layout and marks the workspace loaded', () {
    expect(ws.store.loaded, isTrue);
    expect(ws.store.panels.length, 3);
  });

  test('a drag follows the pointer and rounds to whole cells on release', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 1.4, 0);
    expect(cellOf(ws, p).x, 1, reason: 'the target rounds to the nearest cell');
    expect(ws.store.preview.value!.live.x, closeTo(1.4, 1e-9), reason: 'the live position is exact');
    ws.layout.endGesture();
    expect(p.x, 1);
  });

  test('small movements do not change the target until 60% of a cell', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 0.5, 0);
    expect(cellOf(ws, p).x, 0);
    ws.layout.dragBy(p, 0.7, 0);
    expect(cellOf(ws, p).x, 1);
    ws.layout.endGesture();
  });

  test('a whole drag is one undo step', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    for (var c = 0; c <= 3; c++) {
      ws.layout.dragBy(p, c.toDouble(), 0);
    }
    ws.layout.endGesture();
    expect(p.x, 3);
    ws.layout.undo();
    expect(chart(ws).x, 0, reason: 'one undo should revert the entire drag');
  });

  test('a cancelled drag changes nothing', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 3, 0);
    ws.layout.endGesture();
    final moved = p.x;
    ws.layout.undo();
    expect(moved, 3);
    expect(chart(ws).x, 0);
  });

  test('dragging stops at the right edge of the 12-column grid', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 50, 0);
    expect(cellOf(ws, p).x, 12 - p.w);
    ws.layout.endGesture();
  });

  test('dragging never goes above the top row', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 0, -50);
    expect(cellOf(ws, p).y, 0);
    ws.layout.endGesture();
  });

  test('right-edge resize accumulates and respects grid and minimum size', () {
    final p = chart(ws);
    final w0 = p.w;
    ws.layout.beginGesture(p);
    ws.layout.resizeBy(p, {ResizeSide.right}, 1, 0);
    expect(cellOf(ws, p).w, w0 + 1);
    ws.layout.resizeBy(p, {ResizeSide.right}, 50, 0);
    expect(cellOf(ws, p).w, 12 - p.x);
    ws.layout.resizeBy(p, {ResizeSide.right, ResizeSide.bottom}, -50, -50);
    expect(cellOf(ws, p).w, WidgetKind.chart.minW);
    expect(cellOf(ws, p).h, WidgetKind.chart.minH);
    ws.layout.endGesture();
  });

  test('a gesture on one panel ignores updates for another', () {
    final p = chart(ws);
    final other = ws.store.panels.firstWhere((e) => e.id == 'default-table');
    final before = other.x;
    ws.layout.beginGesture(p);
    ws.layout.dragBy(other, 3, 0);
    expect(cellOf(ws, other).x, before, reason: 'the table was not the active gesture panel');
    ws.layout.endGesture();
  });
}
