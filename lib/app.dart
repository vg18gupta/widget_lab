import 'package:flutter/material.dart';
import 'package:tradl_widget_lab/market/market_store.dart';
import 'package:tradl_widget_lab/state/workspace.dart';
import 'package:tradl_widget_lab/ui/lab_home.dart';

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
    debugShowCheckedModeBanner:false, title:'Tradl Widget Lab',
    theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,
      scaffoldBackgroundColor:const Color(0xff0b1020),
      colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff8b7cff),brightness:Brightness.dark)),
    home:LabHome(workspace:workspace,market:market));
}
