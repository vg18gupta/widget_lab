import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/workspace_store.dart';

void main() {
  late AppControllers ws;
  late Panel chart;
  late Panel table;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ws = AppControllers(market: MarketStore());
    await ws.layout.load();
    chart = ws.store.panels.firstWhere((p) => p.id == 'default-chart');
    table = ws.store.panels.firstWhere((p) => p.id == 'default-table');
  });

  test('table row selection on a shared channel moves the chart', () {
    ws.channels.setChannel(chart, 0);
    ws.channels.setChannel(table, 0);
    ws.channels.selectSymbol(table, 'BBB');
    expect(chart.symbol, 'BBB');
    expect(ws.store.channelSymbols[0].value, 'BBB');
  });

  test('selecting a symbol in an unlinked table changes only that table', () {
    ws.channels.selectSymbol(table, 'CCC');
    expect(table.symbol, 'CCC');
    expect(chart.symbol, 'AAA');
  });

  test('view settings are per widget, never synced', () {
    ws.channels.setChannel(chart, 0);
    ws.channels.setChannel(table, 0);
    chart.range = '15m';
    table.sortBy = 'pct';
    expect(table.range, isNot('15m'));
    expect(chart.sortBy, isNot('pct'));
  });

  test('unlinking keeps the last symbol and stops following the channel', () {
    ws.channels.setChannel(chart, 0);
    ws.channels.setChannel(table, 0);
    ws.channels.selectSymbol(table, 'BBB');
    ws.channels.setChannel(chart, -1);
    ws.channels.selectSymbol(table, 'CCC');
    expect(chart.symbol, 'BBB');
  });

  test('the first widget in an empty channel sets the channel symbol', () {
    chart.symbol = 'BBB'; // unlinked widget showing BBB
    ws.channels.setChannel(chart, 1); // channel 1 has no other members
    expect(ws.store.channelSymbols[1].value, 'BBB');
  });

  test('a channel selection survives a reload', () async {
    ws.channels.setChannel(chart, 0);
    ws.channels.setChannel(table, 0);
    ws.channels.selectSymbol(table, 'BBB');
    await Future<void>.delayed(Duration.zero);
    final reloaded = AppControllers(market: MarketStore());
    await reloaded.layout.load();
    expect(reloaded.store.channelSymbols[0].value, 'BBB');
  });
}
