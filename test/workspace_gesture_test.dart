import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/data/layout_repository.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/store/workspace_store.dart';

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

  test('a drag moves by whole cells from where the gesture began', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 1, 0);
    expect(p.x, 1);
    ws.layout.dragBy(p, 1, 0); // the offset is measured from the start, so this is still one cell
    expect(p.x, 1);
    ws.layout.endGesture();
  });

  test('a whole drag is one undo step', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    for (var c = 0; c <= 3; c++) {
      ws.layout.dragBy(p, c, 0);
    }
    ws.layout.endGesture();
    expect(p.x, 3);
    ws.layout.undo();
    expect(chart(ws).x, 0, reason: 'one undo should revert the entire drag');
  });

  test('dragging stops at the right edge of the 12-column grid', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 50, 0);
    expect(p.x, 12 - p.w);
    expect(p.x + p.w, lessThanOrEqualTo(12));
    ws.layout.endGesture();
  });

  test('dragging never goes above the top row', () {
    final p = chart(ws);
    ws.layout.beginGesture(p);
    ws.layout.dragBy(p, 0, -50);
    expect(p.y, 0);
    ws.layout.endGesture();
  });

  test('right-edge resize accumulates and respects grid and minimum size', () {
    final p = chart(ws);
    final w0 = p.w;
    ws.layout.beginGesture(p);
    ws.layout.resizeBy(p, {ResizeSide.right}, 1, 0);
    expect(p.w, w0 + 1);
    ws.layout.resizeBy(p, {ResizeSide.right}, 50, 0);
    expect(p.w, 12 - p.x);
    ws.layout.resizeBy(p, {ResizeSide.right, ResizeSide.bottom}, -50, -50);
    expect(p.w, WidgetKind.chart.minW);
    expect(p.h, WidgetKind.chart.minH);
    ws.layout.endGesture();
  });

  test('a gesture on one panel ignores updates for another', () {
    final p = chart(ws);
    final other = ws.store.panels.firstWhere((e) => e.id == 'default-table');
    final before = other.x;
    ws.layout.beginGesture(p);
    ws.layout.dragBy(other, 3, 0);
    expect(other.x, before, reason: 'the table was not the active gesture panel');
    ws.layout.endGesture();
  });
}
