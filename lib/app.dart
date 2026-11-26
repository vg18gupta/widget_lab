import 'package:flutter/material.dart';
import 'package:widget_lab/controller/app_controllers.dart';
import 'package:widget_lab/data/frame_budget.dart';
import 'package:widget_lab/presentation/lab_home.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/theme/palette.dart';

/// Creates the market and controllers once, starts the feed, and shows the lab.
class WidgetLabApp extends StatefulWidget {
  const WidgetLabApp({super.key});
  @override State<WidgetLabApp> createState()=>_WidgetLabAppState();
}

class _WidgetLabAppState extends State<WidgetLabApp> {
  late final MarketStore market;
  late final AppControllers app;

  @override void initState() {
    super.initState();
    market=MarketStore();
    market.start();
    app=AppControllers(market: market);
    app.layout.load();
    FrameBudget.instance.attach();
  }

  @override void dispose() {
    FrameBudget.instance.detach();
    app.dispose();
    market.dispose();
    super.dispose();
  }

  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'Widget Lab',
    theme:buildAppTheme(),
    home:LabHome(app:app));
}
