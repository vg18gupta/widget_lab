import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradl_widget_lab/market/market_store.dart';
import 'package:tradl_widget_lab/models/constants.dart';
import 'package:tradl_widget_lab/models/panel.dart';
import 'package:tradl_widget_lab/state/workspace.dart';

bool _overlap(Panel a, Panel b) =>
  a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

void _expectNoOverlaps(Workspace ws) {
  for (var i = 0; i < ws.panels.length; i++) {
    for (var j = i + 1; j < ws.panels.length; j++) {
      expect(_overlap(ws.panels[i], ws.panels[j]), isFalse,
        reason: '${ws.panels[i].id} overlaps ${ws.panels[j].id}');
    }
  }
}

Panel _byId(Workspace ws, String id) => ws.panels.firstWhere((p) => p.id == id);

void main() {
  late Workspace ws;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ws = Workspace(MarketStore());
    await ws.load();
  });

  test('removing a widget closes the gap it leaves', () {
    ws.addAt(WidgetKind.table, 0, 20); // far below the defaults, leaving a gap
    final table = ws.panels.last;
    expect(table.y, 20);
    ws.remove(_byId(ws, 'default-script')); // script occupied y7..13 at x0
    expect(table.y, 7, reason: 'the table should rise into the freed space');
    _expectNoOverlaps(ws);
  });

  test('a dropped widget lands exactly on its cell and others settle around it', () {
    ws.addAt(WidgetKind.chart, 0, 0);
    final dropped = ws.panels.last;
    expect(dropped.x, 0);
    expect(dropped.y, 0);
    expect(dropped.w, WidgetKind.chart.defaultW);
    _expectNoOverlaps(ws);
  });

  test('a dropped widget is clamped inside the grid', () {
    ws.addAt(WidgetKind.table, 11, 0);
    final dropped = ws.panels.last;
    expect(dropped.x + dropped.w, lessThanOrEqualTo(12));
  });

  test('full screen toggles on and off and only one panel is full screen', () {
    final chart = _byId(ws, 'default-chart');
    final table = _byId(ws, 'default-table');
    expect(ws.fullscreenPanel, isNull);
    ws.toggleFullscreen(chart);
    expect(ws.fullscreenPanel, same(chart));
    ws.toggleFullscreen(table);
    expect(ws.fullscreenPanel, same(table));
    expect(chart.fullscreen, isFalse);
    ws.toggleFullscreen(table);
    expect(ws.fullscreenPanel, isNull);
  });

  test('each widget kind stops at its own minimum size', () {
    const cellW = 60.0;
    final table = _byId(ws, 'default-table');
    ws.beginGesture(table);
    ws.resizeBy(table, {ResizeSide.right, ResizeSide.bottom}, -5000, -5000, cellW);
    expect(table.w, WidgetKind.table.minW);
    expect(table.h, WidgetKind.table.minH);
    ws.endGesture();

    final script = _byId(ws, 'default-script');
    ws.beginGesture(script);
    ws.resizeBy(script, {ResizeSide.right, ResizeSide.bottom}, -5000, -5000, cellW);
    expect(script.w, WidgetKind.script.minW);
    expect(script.h, WidgetKind.script.minH);
    ws.endGesture();
  });

  test('a left-edge resize keeps the right edge fixed', () {
    const cellW = 60.0;
    final chart = _byId(ws, 'default-chart'); // x0, right edge at chart.w
    final rightEdge = chart.x + chart.w;
    ws.beginGesture(chart);
    ws.resizeBy(chart, {ResizeSide.left}, 60, 0, cellW); // one cell in
    expect(chart.x, 1);
    expect(chart.x + chart.w, rightEdge);
    ws.endGesture();
  });

  test('a top-edge resize keeps the bottom edge fixed', () {
    final chart = _byId(ws, 'default-chart'); // y0 h7, bottom edge at 7
    ws.beginGesture(chart);
    ws.resizeBy(chart, {ResizeSide.top}, 0, rowHeight, 60); // one row down
    expect(chart.y, 1);
    expect(chart.y + chart.h, 7);
    ws.endGesture();
  });
}
