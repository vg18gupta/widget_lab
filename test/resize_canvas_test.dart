import 'package:widget_lab/controller/app_controllers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/app.dart';
import 'package:widget_lab/presentation/panel_card.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/store/workspace_store.dart';
import 'package:widget_lab/presentation/lab_home.dart';

void main() {
  testWidgets('every edge and corner resizes a widget on the full canvas with a mouse', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});
    final market = MarketStore();
    final ws = AppControllers(market: market);
    await tester.runAsync(() => ws.layout.load());
    await tester.pumpWidget(MaterialApp(home: LabHome(app: ws)));
    await tester.pump();

    final chart = ws.store.panels.firstWhere((p) => p.id == 'default-chart');
    final finder = find.byWidgetPredicate((w) => w is PanelCard && w.key == const ValueKey('default-chart'));
    Future<void> mouseDrag(Offset from, Offset by) async {
      final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
      await g.moveBy(by);
      await g.up();
      await tester.pump();
    }

    // Reset to the original position between checks.
    final w0 = chart.w, h0 = chart.h;
    Future<void> reset() async {
      chart.x = 0; chart.y = 0; chart.w = w0; chart.h = h0;
      await tester.pump();
    }

    var rect = tester.getRect(finder);
    await mouseDrag(Offset(rect.right - 3, rect.bottom - 3), const Offset(90, 0));
    expect(chart.w, greaterThan(w0), reason: 'bottom-right corner');
    await reset();

    rect = tester.getRect(finder);
    await mouseDrag(Offset(rect.right - 3, rect.center.dy), const Offset(90, 0));
    expect(chart.w, greaterThan(w0), reason: 'right edge');
    await reset();

    rect = tester.getRect(finder);
    await mouseDrag(Offset(rect.left + 3, rect.center.dy), const Offset(90, 0));
    expect(chart.x, greaterThan(0), reason: 'left edge');
    await reset();

    rect = tester.getRect(finder);
    await mouseDrag(Offset(rect.center.dx, rect.top + 3), const Offset(0, 72));
    expect(chart.y, greaterThan(0), reason: 'top edge');
    await reset();
  });
}
