import 'package:widget_lab/domain/grid_layout.dart';

/// A drag or resize in progress. The canvas reads this instead of the layout, so moving the
/// pointer changes only the positions that move. Releasing the pointer commits it.
class GesturePreview {
  const GesturePreview({required this.panelId, required this.live, required this.cells});

  /// The widget under the pointer.
  final String panelId;

  /// Where that widget is following the pointer, in fractional cells.
  final LiveRect live;

  /// Where every widget would end up if the gesture were released now, in whole cells.
  final Map<String, CellRect> cells;
}
