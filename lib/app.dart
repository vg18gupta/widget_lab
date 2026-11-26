import 'package:flutter/material.dart';
import 'package:widget_lab/market/market_store.dart';
import 'package:widget_lab/state/workspace.dart';
import 'package:widget_lab/theme/palette.dart';
import 'package:widget_lab/ui/lab_home.dart';

class WidgetLabApp extends StatefulWidget {
  const WidgetLabApp({super.key});
  @override State<WidgetLabApp> createState()=>_WidgetLabAppState();
}
class _WidgetLabAppState extends State<WidgetLabApp> {
  late final MarketStore market;
  late final Workspace workspace;
  @override void initState() {
    super.initState();
    market=MarketStore(); market.start();
    workspace=Workspace(market); workspace.load();
  }
  @override void dispose() { workspace.dispose(); market.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner:false, title:'Widget Lab',
    theme:buildAppTheme(),
    home:LabHome(workspace:workspace,market:market));
}
