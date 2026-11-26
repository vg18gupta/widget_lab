import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/workspace_store.dart';
import 'package:widget_lab/presentation/lab_home.dart';

/// Measures the CPU time spent per frame with eight widgets, with the feed running
/// and with it paused. Debug-mode numbers are inflated; compare them relative to each other.
void main() {
  testWidgets('frame cost with eight widgets: feed running vs paused', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});

    final market = MarketStore();
    addTearDown(market.dispose);
    final ws = AppControllers(market: market);
    await tester.runAsync(() => ws.layout.load());
    for (final k in [WidgetKind.chart, WidgetKind.table, WidgetKind.chart, WidgetKind.script, WidgetKind.chart]) {
      ws.layout.add(k);
    }
    await tester.pumpWidget(MaterialApp(home: LabHome(app: ws)));
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

    // Warm up, then measure the running feed and the paused feed over the same frames.
    await measure(50);
    final (runMs, ticks) = await measure(300);
    market.configure(pause: true);
    await tester.pump();
    final (pausedMs, _) = await measure(300);

    // ignore: avoid_print
    print('feed running: ${runMs.toStringAsFixed(2)} ms/frame over $ticks ticks');
    // ignore: avoid_print
    print('feed paused:  ${pausedMs.toStringAsFixed(2)} ms/frame');
    expect(ticks, greaterThan(5));
  });
}
