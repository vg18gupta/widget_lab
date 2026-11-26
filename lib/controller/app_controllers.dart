import 'package:widget_lab/controller/channel_controller.dart';
import 'package:widget_lab/controller/chart_controller.dart';
import 'package:widget_lab/controller/layout_controller.dart';
import 'package:widget_lab/controller/layout_persistence.dart';
import 'package:widget_lab/controller/script_controller.dart';
import 'package:widget_lab/controller/table_controller.dart';
import 'package:widget_lab/data/layout_repository.dart';
import 'package:widget_lab/store/market_store.dart';
import 'package:widget_lab/store/workspace_store.dart';

/// The app's stores and controllers, built once. The presentation layer receives this and
/// calls controllers; it never changes the stores directly.
class AppControllers {
  AppControllers({required this.market, LayoutRepository? repository}) {
    persistence = LayoutPersistence(repository ?? SharedPrefsLayoutRepository());
    layout = LayoutController(store, persistence);
    channels = ChannelController(store, persistence);
    script = ScriptController(store, persistence);
  }

  final MarketStore market;
  final WorkspaceStore store = WorkspaceStore();
  late final LayoutPersistence persistence;
  late final LayoutController layout;
  late final ChannelController channels;
  late final ScriptController script;
  final TableController table = TableController();
  final ChartController charts = ChartController();

  void dispose() => store.dispose();
}
