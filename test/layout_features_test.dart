import 'package:widget_lab/controller/app_controllers.dart';
import 'support/cells.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/config/constants.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/store/workspace_store.dart';

bool _overlap(Panel a, Panel b) =>
  a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

void _expectNoOverlaps(AppControllers ws) {
  for (var i = 0; i < ws.store.panels.length; i++) {
    for (var j = i + 1; j < ws.store.panels.length; j++) {
      expect(_overlap(ws.store.panels[i], ws.store.panels[j]), isFalse,
        reason: '${ws.store.panels[i].id} overlaps ${ws.store.panels[j].id}');
    }
  }
}

Panel _byId(AppControllers ws, String id) => ws.store.panels.firstWhere((p) => p.id == id);

void main() {
  late AppControllers ws;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ws = AppControllers(market: MarketStore());
    await ws.layout.load();
  });

  test('removing a widget closes the gap it leaves', () {
    ws.layout.addAt(WidgetKind.table, 0, 20); // far below the defaults, leaving a gap
    final table = ws.store.panels.last;
    expect(table.y, 20);
    ws.layout.remove(_byId(ws, 'default-script')); // script occupied y7..13 at x0
    expect(table.y, 7, reason: 'the table should rise into the freed space');
    _expectNoOverlaps(ws);
  });

  test('a dropped widget lands exactly on its cell and others settle around it', () {
    ws.layout.addAt(WidgetKind.chart, 0, 0);
    final dropped = ws.store.panels.last;
    expect(dropped.x, 0);
    expect(dropped.y, 0);
    expect(dropped.w, WidgetKind.chart.defaultW);
    _expectNoOverlaps(ws);
  });

  test('a dropped widget is clamped inside the grid', () {
    ws.layout.addAt(WidgetKind.table, 11, 0);
    final dropped = ws.store.panels.last;
    expect(dropped.x + dropped.w, lessThanOrEqualTo(12));
  });

  test('full screen toggles on and off and only one panel is full screen', () {
    final chart = _byId(ws, 'default-chart');
    final table = _byId(ws, 'default-table');
    expect(ws.store.fullscreenPanel, isNull);
    ws.layout.toggleFullscreen(chart);
    expect(ws.store.fullscreenPanel, same(chart));
    ws.layout.toggleFullscreen(table);
    expect(ws.store.fullscreenPanel, same(table));
    expect(chart.fullscreen, isFalse);
    ws.layout.toggleFullscreen(table);
    expect(ws.store.fullscreenPanel, isNull);
  });

  test('each widget kind stops at its own minimum size', () {
    final table = _byId(ws, 'default-table');
    ws.layout.beginGesture(table);
    ws.layout.resizeBy(table, {ResizeSide.right, ResizeSide.bottom}, -50, -50);
    expect(cellOf(ws, table).w, WidgetKind.table.minW);
    expect(cellOf(ws, table).h, WidgetKind.table.minH);
    ws.layout.endGesture();

    final script = _byId(ws, 'default-script');
    ws.layout.beginGesture(script);
    ws.layout.resizeBy(script, {ResizeSide.right, ResizeSide.bottom}, -50, -50);
    expect(cellOf(ws, script).w, WidgetKind.script.minW);
    expect(cellOf(ws, script).h, WidgetKind.script.minH);
    ws.layout.endGesture();
  });

  test('a left-edge resize keeps the right edge fixed', () {
    final chart = _byId(ws, 'default-chart'); // x0, right edge at chart.w
    final rightEdge = rectOf(chart).x + rectOf(chart).w;
    ws.layout.beginGesture(chart);
    ws.layout.resizeBy(chart, {ResizeSide.left}, 1, 0); // one cell in
    expect(cellOf(ws, chart).x, 1);
    expect(cellOf(ws, chart).x + cellOf(ws, chart).w, rightEdge);
    ws.layout.endGesture();
  });

  test('a top-edge resize keeps the bottom edge fixed', () {
    final chart = _byId(ws, 'default-chart'); // y0 h7, bottom edge at 7
    ws.layout.beginGesture(chart);
    ws.layout.resizeBy(chart, {ResizeSide.top}, 0, 1); // one row down
    expect(cellOf(ws, chart).y, 1);
    expect(cellOf(ws, chart).y + cellOf(ws, chart).h, 7);
    ws.layout.endGesture();
  });
}
