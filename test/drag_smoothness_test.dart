import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/controller/app_controllers.dart';
import 'package:widget_lab/presentation/lab_home.dart';
import 'package:widget_lab/presentation/panel_card.dart';
import 'package:widget_lab/store/market_store.dart';

void main() {
  testWidgets('during a drag, cards and charts do not rebuild and the card follows the pointer exactly',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    SharedPreferences.setMockInitialValues({});

    final market = MarketStore();
    addTearDown(market.dispose);
    final app = AppControllers(market: market);
    await tester.runAsync(() => app.layout.load());
    await tester.pumpWidget(MaterialApp(home: LabHome(app: app)));
    await tester.pump(const Duration(milliseconds: 300));

    final finder = find.byWidgetPredicate((w) => w is PanelCard && w.key == const ValueKey('default-chart'));
    final rect = tester.getRect(finder);
    final start = tester.getTopLeft(finder);

    final g = await tester.startGesture(rect.topLeft + const Offset(40, 20), kind: PointerDeviceKind.mouse);
    await g.moveBy(const Offset(4, 0)); // past the drag threshold, but within the first cell
    await tester.pump();
    panelBuildCounts.clear();
    for (var i = 1; i <= 20; i++) {
      await g.moveBy(const Offset(2, 0));
      await tester.pump();
    }
    expect(panelBuildCounts['card'] ?? 0, 0, reason: 'a pointer move must not rebuild cards');
    expect(panelBuildCounts['chart'] ?? 0, 0, reason: 'a pointer move must not redraw charts');

    final now = tester.getTopLeft(finder);
    expect(now.dx - start.dx, closeTo(44, 0.5), reason: 'the card follows the pointer, not the cell grid');
    await g.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(app.store.preview.value, isNull, reason: 'the gesture ends and the preview is cleared');
  });
}
