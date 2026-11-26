import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/config/constants.dart';
import 'package:widget_lab/store/workspace_store.dart';
import 'package:widget_lab/data/frame_budget.dart';
import 'package:widget_lab/presentation/panel_card.dart';

void _frames(FrameBudget b, int count, int ms) {
  for (var i = 0; i < count; i++) {
    b.record(Duration(milliseconds: ms));
  }
}

void main() {
  group('FrameBudget', () {
    setUp(() => FrameBudget.instance.reset());

    test('starts within budget', () {
      expect(FrameBudget.instance.overBudget, isFalse);
    });

    test('goes over budget when the recent average exceeds 16 ms', () {
      _frames(FrameBudget.instance, 10, 30);
      expect(FrameBudget.instance.overBudget, isTrue);
    });

    test('does not decide until a full window of frames is recorded', () {
      _frames(FrameBudget.instance, 9, 30);
      expect(FrameBudget.instance.overBudget, isFalse);
    });

    test('hysteresis: a frame time between 12 and 16 ms keeps it over budget', () {
      _frames(FrameBudget.instance, 10, 30);
      _frames(FrameBudget.instance, 10, 14);
      expect(FrameBudget.instance.overBudget, isTrue);
    });

    test('comes back within budget once the average falls below 12 ms', () {
      _frames(FrameBudget.instance, 10, 30);
      _frames(FrameBudget.instance, 10, 8);
      expect(FrameBudget.instance.overBudget, isFalse);
    });
  });

  testWidgets('over budget, a chart batches its redraws; within budget it does not', (tester) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(() => FrameBudget.instance.reset());
    final market = MarketStore();
    addTearDown(market.dispose);
    final ws = AppControllers(market: market)..layout.reset(notify: false);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 600, height: 420,
        child: PanelCard(panel: ws.store.panels.first, app: ws,
          cellW: 50, interactive: true))))));
    market.start();
    await tester.pump();

    Future<(int, int)> measure() async {
      panelBuildCounts.clear();
      final before = market.batch.value;
      for (var i = 0; i < 200; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      return (market.batch.value - before, panelBuildCounts['chart'] ?? 0);
    }

    FrameBudget.instance.reset();
    final (ticksFast, drawsFast) = await measure();
    expect(drawsFast, ticksFast, reason: 'within budget: every tick draws');

    _frames(FrameBudget.instance, 10, 30);
    final (ticksSlow, drawsSlow) = await measure();
    expect(ticksSlow, greaterThan(5));
    expect(drawsSlow, lessThan(ticksSlow ~/ 2), reason: 'over budget: at most one draw per 100 ms');
    expect(drawsSlow, greaterThanOrEqualTo(2));
    expect(chartRedrawInterval, Duration.zero, reason: 'the user setting is untouched');
  });
}
