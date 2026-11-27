import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/controller/app_controllers.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/market_store.dart';
import 'support/cells.dart';

bool _overlap(CellRect a, CellRect b) =>
  a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a panel pushed aside by a drag returns when the drag moves away', () async {
    final ws = AppControllers(market: MarketStore());
    await ws.layout.load();
    final chart = ws.store.panels.firstWhere((p) => p.id == 'default-chart');
    final table = ws.store.panels.firstWhere((p) => p.id == 'default-table');

    ws.layout.beginGesture(chart);
    ws.layout.dragBy(chart, 4, 0); // chart now spans x4..8 and overlaps the table
    expect(cellOf(ws, chart).x, 4);
    expect(_overlap(cellOf(ws, chart), cellOf(ws, table)), isFalse,
      reason: 'the table must be pushed clear');
    expect(cellOf(ws, table).y, 7);

    ws.layout.dragBy(chart, 0, 0); // drag back to the start
    expect(cellOf(ws, table).y, 0, reason: 'the table returns once the chart no longer overlaps it');
    ws.layout.endGesture();
  });

  test('a new widget is placed below the existing ones, not on top of them', () async {
    final ws = AppControllers(market: MarketStore());
    await ws.layout.load();
    ws.layout.add(WidgetKind.chart);
    final added = ws.store.panels.last;
    for (final other in ws.store.panels.where((p) => !identical(p, added))) {
      expect(_overlap(rectOf(added), rectOf(other)), isFalse);
    }
  });
}
