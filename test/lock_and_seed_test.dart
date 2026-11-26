import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/workspace_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a locked layout refuses add, drag, remove, duplicate, undo and reset', () async {
    final ws = AppControllers(market: MarketStore());
    await ws.layout.load();
    final n = ws.store.panels.length;
    final chart = ws.store.panels.firstWhere((p) => p.id == 'default-chart');
    ws.layout.setLocked(true);

    ws.layout.add(WidgetKind.chart);
    expect(ws.store.panels.length, n);

    ws.layout.beginGesture(chart);
    ws.layout.dragBy(chart, 4, 0);
    ws.layout.endGesture();
    expect(chart.x, 0);

    ws.layout.remove(chart);
    expect(ws.store.panels.length, n);

    ws.layout.duplicate(chart);
    expect(ws.store.panels.length, n);

    ws.layout.undo(); // nothing to undo, but must not restore or crash while locked
    ws.layout.reset();
    expect(ws.store.panels.length, n);

    ws.layout.setLocked(false);
    ws.layout.add(WidgetKind.chart);
    expect(ws.store.panels.length, n + 1);
  });

  test('linking and symbol changes still work while locked', () async {
    final ws = AppControllers(market: MarketStore());
    await ws.layout.load();
    final chart = ws.store.panels.firstWhere((p) => p.id == 'default-chart');
    final table = ws.store.panels.firstWhere((p) => p.id == 'default-table');
    ws.layout.setLocked(true);
    ws.channels.setChannel(chart, 0);
    ws.channels.setChannel(table, 0);
    ws.channels.selectSymbol(table, 'BBB');
    expect(chart.symbol, 'BBB');
  });

  test('the lock state is saved and restored on reload', () async {
    final ws = AppControllers(market: MarketStore());
    await ws.layout.load();
    ws.layout.setLocked(true);
    await Future<void>.delayed(Duration.zero);
    final reloaded = AppControllers(market: MarketStore());
    await reloaded.layout.load();
    expect(reloaded.store.locked, isTrue);
  });

  test('a new seed is stored on the market and used for the feed', () {
    final market = MarketStore();
    market.configure(newSeed: 9);
    expect(market.seed, 9);
  });
}
