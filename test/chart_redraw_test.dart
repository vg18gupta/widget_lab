import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/market/market_store.dart';
import 'package:widget_lab/models/constants.dart';
import 'package:widget_lab/state/workspace.dart';
import 'package:widget_lab/ui/panel_card.dart';

Future<void> _pumpChart(WidgetTester tester, MarketStore market, Workspace ws) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
    child: SizedBox(width: 600, height: 420,
      child: PanelCard(panel: ws.panels.first, workspace: ws, market: market,
        cellW: 50, interactive: true))))));
}

void main() {
  tearDown(() => chartRedrawInterval = Duration.zero);

  testWidgets('by default a chart redraws on every feed tick', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final market = MarketStore();
    addTearDown(market.dispose);
    final ws = Workspace(market)..reset(notify: false);
    await _pumpChart(tester, market, ws);
    market.start();
    await tester.pump();

    panelBuildCounts.clear();
    final before = market.batch.value;
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final ticks = market.batch.value - before;
    expect(ticks, greaterThan(5));
    expect(panelBuildCounts['chart'], ticks);
  });

  testWidgets('with a 500 ms cap a chart redraws about every 500 ms and still ends on the latest data', (tester) async {
    SharedPreferences.setMockInitialValues({});
    chartRedrawInterval = const Duration(milliseconds: 500);
    final market = MarketStore();
    addTearDown(market.dispose);
    final ws = Workspace(market)..reset(notify: false);
    await _pumpChart(tester, market, ws);
    market.start();
    await tester.pump();

    panelBuildCounts.clear();
    final before = market.batch.value;
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final ticks = market.batch.value - before;
    final draws = panelBuildCounts['chart'] ?? 0;
    expect(ticks, greaterThan(5));
    expect(draws, lessThan(ticks ~/ 2), reason: 'a 500 ms cap should skip most ticks');
    expect(draws, greaterThanOrEqualTo(2));
  });
}
