import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/market/market_store.dart';
import 'package:widget_lab/models/panel.dart';
import 'package:widget_lab/state/workspace.dart';

void main() {
  late Workspace ws;
  late Panel chart;
  late Panel table;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ws = Workspace(MarketStore());
    await ws.load();
    chart = ws.panels.firstWhere((p) => p.id == 'default-chart');
    table = ws.panels.firstWhere((p) => p.id == 'default-table');
  });

  test('table row selection on a shared channel moves the chart', () {
    ws.setChannel(chart, 0);
    ws.setChannel(table, 0);
    ws.selectSymbol(table, 'BBB');
    expect(chart.symbol, 'BBB');
    expect(ws.channelSymbols[0].value, 'BBB');
  });

  test('selecting a symbol in an unlinked table changes only that table', () {
    ws.selectSymbol(table, 'CCC');
    expect(table.symbol, 'CCC');
    expect(chart.symbol, 'AAA');
  });

  test('view settings are per widget, never synced', () {
    ws.setChannel(chart, 0);
    ws.setChannel(table, 0);
    chart.range = '15m';
    table.sortBy = 'pct';
    expect(table.range, isNot('15m'));
    expect(chart.sortBy, isNot('pct'));
  });

  test('unlinking keeps the last symbol and stops following the channel', () {
    ws.setChannel(chart, 0);
    ws.setChannel(table, 0);
    ws.selectSymbol(table, 'BBB');
    ws.setChannel(chart, -1);
    ws.selectSymbol(table, 'CCC');
    expect(chart.symbol, 'BBB');
  });

  test('the first widget in an empty channel sets the channel symbol', () {
    chart.symbol = 'BBB'; // unlinked widget showing BBB
    ws.setChannel(chart, 1); // channel 1 has no other members
    expect(ws.channelSymbols[1].value, 'BBB');
  });

  test('a channel selection survives a reload', () async {
    ws.setChannel(chart, 0);
    ws.setChannel(table, 0);
    ws.selectSymbol(table, 'BBB');
    await Future<void>.delayed(Duration.zero);
    final reloaded = Workspace(MarketStore());
    await reloaded.load();
    expect(reloaded.channelSymbols[0].value, 'BBB');
  });
}
