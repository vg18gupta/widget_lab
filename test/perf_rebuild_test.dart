import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/workspace_store.dart';
import 'package:widget_lab/presentation/lab_home.dart';
import 'package:widget_lab/presentation/panel_card.dart';

void main() {
  testWidgets('with eight widgets, each feed tick rebuilds only the charts and tables, once each', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});

    final market = MarketStore();
    addTearDown(market.dispose);
    final ws = AppControllers(market: market);
    await tester.runAsync(() => ws.layout.load());
    // Default layout (chart, table, script) plus five more: 4 charts, 2 tables, 2 scripts.
    for (final k in [WidgetKind.chart, WidgetKind.table, WidgetKind.chart, WidgetKind.script, WidgetKind.chart]) {
      ws.layout.add(k);
    }
    expect(ws.store.panels.length, 8);

    await tester.pumpWidget(MaterialApp(home: LabHome(app: ws)));
    await tester.pump();

    market.start();
    await tester.pump();
    panelBuildCounts.clear();
    final tickBefore = market.batch.value;
    // Pump in short steps so each feed tick (every 150 ms) gets its own frame, as in the app.
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final ticks = market.batch.value - tickBefore;
    // ignore: avoid_print
    print('ticks: $ticks, builds: $panelBuildCounts');

    expect(ticks, greaterThan(5), reason: 'the feed should tick during the test');
    expect(panelBuildCounts['card'] ?? 0, 0, reason: 'panel cards must not rebuild on a tick');
    expect(panelBuildCounts['script'] ?? 0, 0, reason: 'scripts must not rebuild on a tick');
    expect(panelBuildCounts['chart'], 4 * ticks, reason: 'each of 4 charts once per tick');
    expect(panelBuildCounts['table'], 2 * ticks, reason: 'each of 2 tables once per tick');
  });
}
