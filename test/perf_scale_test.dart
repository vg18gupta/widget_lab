import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/market/market_store.dart';
import 'package:widget_lab/models/panel.dart';
import 'package:widget_lab/state/workspace.dart';
import 'package:widget_lab/ui/lab_home.dart';

/// Frame cost with N widgets, feed running vs paused. Debug-mode test numbers:
/// compare before and after changes on the same machine, not against the browser.
Future<void> _measure(WidgetTester tester, int extra) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  SharedPreferences.setMockInitialValues({});

  final market = MarketStore();
  addTearDown(market.dispose);
  final ws = Workspace(market);
  await tester.runAsync(() => ws.load());
  const cycle = [WidgetKind.chart, WidgetKind.table, WidgetKind.chart, WidgetKind.script, WidgetKind.chart];
  for (var i = 0; i < extra; i++) {
    ws.add(cycle[i % cycle.length]);
  }
  await tester.pumpWidget(MaterialApp(home: LabHome(workspace: ws, market: market)));
  await tester.pump();
  market.start();
  await tester.pump();

  Future<(double, int)> measure(int frames) async {
    final before = market.batch.value;
    final sw = Stopwatch()..start();
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    sw.stop();
    return (sw.elapsedMicroseconds / 1000 / frames, market.batch.value - before);
  }

  await measure(50);
  final (runMs, ticks) = await measure(300);
  market.configure(pause: true);
  await tester.pump();
  final (pausedMs, _) = await measure(300);
  // ignore: avoid_print
  print('${ws.panels.length} widgets: running ${runMs.toStringAsFixed(2)} ms/frame '
      '(${ticks} ticks in 300 frames), paused ${pausedMs.toStringAsFixed(2)} ms/frame');
  expect(ticks, greaterThan(5));
}

void main() {
  testWidgets('frame cost with 8 widgets', (tester) => _measure(tester, 5));
  testWidgets('frame cost with 16 widgets', (tester) => _measure(tester, 13));
}
