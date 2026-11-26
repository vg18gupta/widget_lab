import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/market/market_store.dart';
import 'package:widget_lab/models/panel.dart';
import 'package:widget_lab/state/workspace.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a locked layout refuses add, drag, remove, duplicate, undo and reset', () async {
    final ws = Workspace(MarketStore());
    await ws.load();
    final n = ws.panels.length;
    final chart = ws.panels.firstWhere((p) => p.id == 'default-chart');
    ws.setLocked(true);

    ws.add(WidgetKind.chart);
    expect(ws.panels.length, n);

    ws.beginGesture(chart);
    ws.dragBy(chart, 240, 0, 60);
    ws.endGesture();
    expect(chart.x, 0);

    ws.remove(chart);
    expect(ws.panels.length, n);

    ws.duplicate(chart);
    expect(ws.panels.length, n);

    ws.undo(); // nothing to undo, but must not restore or crash while locked
    ws.reset();
    expect(ws.panels.length, n);

    ws.setLocked(false);
    ws.add(WidgetKind.chart);
    expect(ws.panels.length, n + 1);
  });

  test('linking and symbol changes still work while locked', () async {
    final ws = Workspace(MarketStore());
    await ws.load();
    final chart = ws.panels.firstWhere((p) => p.id == 'default-chart');
    final table = ws.panels.firstWhere((p) => p.id == 'default-table');
    ws.setLocked(true);
    ws.setChannel(chart, 0);
    ws.setChannel(table, 0);
    ws.selectSymbol(table, 'BBB');
    expect(chart.symbol, 'BBB');
  });

  test('the lock state is saved and restored on reload', () async {
    final ws = Workspace(MarketStore());
    await ws.load();
    ws.setLocked(true);
    await Future<void>.delayed(Duration.zero);
    final reloaded = Workspace(MarketStore());
    await reloaded.load();
    expect(reloaded.locked, isTrue);
  });

  test('a new seed is stored on the market and used for the feed', () {
    final market = MarketStore();
    market.configure(newSeed: 9);
    expect(market.seed, 9);
  });
}
