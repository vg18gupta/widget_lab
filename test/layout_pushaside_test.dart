import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tradl_widget_lab/market/market_store.dart';
import 'package:tradl_widget_lab/models/panel.dart';
import 'package:tradl_widget_lab/state/workspace.dart';

bool _overlap(Panel a, Panel b) =>
  a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a panel pushed aside by a drag returns when the drag moves away', () async {
    final ws = Workspace(MarketStore());
    await ws.load();
    final chart = ws.panels.firstWhere((p) => p.id == 'default-chart'); // x0 y0 w6 h7
    final table = ws.panels.firstWhere((p) => p.id == 'default-table'); // x6 y0 w6 h7

    ws.beginGesture(chart);
    ws.dragBy(chart, 240, 0, 60); // 4 cells right: chart now spans x4..10 and overlaps the table
    expect(chart.x, 4);
    expect(_overlap(chart, table), isFalse, reason: 'the table must be pushed clear');
    expect(table.y, 7);

    ws.dragBy(chart, 0, 0, 60); // drag back to the start
    expect(table.y, 0, reason: 'the table returns once the chart no longer overlaps it');
    ws.endGesture();
  });

  test('a new widget is placed below the existing ones, not on top of them', () async {
    final ws = Workspace(MarketStore());
    await ws.load();
    ws.add(WidgetKind.chart);
    final added = ws.panels.last;
    for (final other in ws.panels.where((p) => !identical(p, added))) {
      expect(_overlap(added, other), isFalse);
    }
  });
}
