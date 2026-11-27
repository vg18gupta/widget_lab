import 'package:widget_lab/controller/app_controllers.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';

/// Where [p] is right now: its position in the gesture preview while a gesture is in
/// progress, otherwise its committed cell.
CellRect cellOf(AppControllers ws, Panel p) => ws.store.preview.value?.cells[p.id] ?? rectOf(p);
