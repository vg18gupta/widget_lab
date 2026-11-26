import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/domain/tick.dart';
import 'package:widget_lab/store/workspace_store.dart';
import 'package:widget_lab/presentation/panel_card.dart';
import 'package:widget_lab/presentation/widget_error.dart';

/// A market whose history can't be read, to simulate a failing data source.
class _BrokenMarket extends MarketStore {
  @override
  List<Tick> history(String s, String range) => throw StateError('feed snapshot unavailable');
}

void main() {
  testWidgets('a failing chart shows its own error state; the table beside it keeps working', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final good = MarketStore();
    addTearDown(good.dispose);
    final broken = _BrokenMarket();
    addTearDown(broken.dispose);
    // Each card gets its own app: the chart reads the broken market, the table the good one.
    final brokenApp = AppControllers(market: broken);
    final goodApp = AppControllers(market: good);
    goodApp.layout.reset(notify: false);
    final chart = goodApp.store.panels[0];
    final table = goodApp.store.panels[1];

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Row(children: [
      SizedBox(width: 400, height: 400, child: PanelCard(panel: chart, app: brokenApp,
        cellW: 50, interactive: false)),
      SizedBox(width: 400, height: 400, child: PanelCard(panel: table, app: goodApp,
        cellW: 50, interactive: false)),
    ]))));
    await tester.pump();

    expect(find.text('Widget error'), findsOneWidget, reason: 'the chart shows its error state');
    expect(find.textContaining('SYMBOL'), findsOneWidget, reason: 'the table still renders');
    expect(find.text('Retry'), findsOneWidget, reason: 'the error offers a retry');
    expect(tester.takeException(), isNull, reason: 'the failure is handled, not left uncaught');
  });

  testWidgets('a widget that throws while building is replaced by the error tile; its siblings survive', (tester) async {
    final previous = ErrorWidget.builder;
    ErrorWidget.builder = (details) => WidgetErrorTile(message: details.exceptionAsString());
    addTearDown(() => ErrorWidget.builder = previous);

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
      const Text('still here'),
      Builder(builder: (_) => throw StateError('boom')),
    ]))));

    expect(tester.takeException(), isA<StateError>());
    expect(find.text('still here'), findsOneWidget, reason: 'the sibling is not affected');
    expect(find.text('Widget error'), findsOneWidget, reason: 'the failing widget shows the tile');
  });
}
