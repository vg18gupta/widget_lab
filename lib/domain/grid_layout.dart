import 'dart:math';
import 'package:widget_lab/domain/panel.dart';

/// Pure grid rules. Everything here works in cells, never pixels.

/// Number of columns in the grid.
const gridColumns = 12;

/// Largest height a widget can be resized to, in rows.
const maxRows = 12;

/// A rectangle in whole cells.
typedef CellRect = ({int x, int y, int w, int h});

/// A rectangle in fractional cells: where a gesture has taken a widget, before it snaps.
typedef LiveRect = ({double x, double y, double w, double h});

/// The edges a resize gesture moves. Corners use two sides.
enum ResizeSide { left, right, top, bottom }

CellRect rectOf(Panel p) => (x: p.x, y: p.y, w: p.w, h: p.h);

LiveRect liveRectOf(CellRect r) =>
  (x: r.x.toDouble(), y: r.y.toDouble(), w: r.w.toDouble(), h: r.h.toDouble());

/// [v] limited to [lo]..[hi]. Unlike `clamp`, never throws if the bounds conflict.
int within(int v, int lo, int hi) => min(max(v, lo), max(lo, hi));

double _clampD(double v, double lo, double hi) => min(max(v, lo), max(lo, hi));

bool overlaps(CellRect a, CellRect b) =>
  a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

/// Tidy layout. [fixed] keeps its exact cell. Every other panel is placed in turn,
/// top to bottom, in the highest free row that doesn't overlap a panel already placed.
/// So panels move aside for [fixed], return when it moves away, and gaps close.
/// Changes the panels in [items] in place.
void settle(List<Panel> items, Panel? fixed) {
  final placed = <CellRect>[if (fixed != null) rectOf(fixed)];
  final rest = items.where((q) => !identical(q, fixed)).toList()
    ..sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
  for (final q in rest) {
    q.y = 0;
    while (placed.any((f) => overlaps(rectOf(q), f))) {
      q.y++;
    }
    placed.add(rectOf(q));
  }
}

/// The layout a new user starts with: a chart, a table and a script across the top.
List<Panel> defaultLayout() => [
  Panel(id: 'default-chart', kind: WidgetKind.chart, x: 0, y: 0, w: 4, h: 7),
  Panel(id: 'default-table', kind: WidgetKind.table, x: 4, y: 0, w: 4, h: 7),
  Panel(id: 'default-script', kind: WidgetKind.script, x: 8, y: 0, w: 4, h: 7),
];

/// Where a dragged widget is, in fractional cells, after the pointer has moved
/// [dCols] and [dRows] cells from where the drag began. Stays inside the grid.
LiveRect liveDragRect(CellRect origin, double dCols, double dRows) => (
  x: _clampD(origin.x + dCols, 0, gridColumns - origin.w.toDouble()),
  y: _clampD(origin.y + dRows, 0, double.infinity),
  w: origin.w.toDouble(),
  h: origin.h.toDouble(),
);

/// Where a resized widget is, in fractional cells. The edges that aren't being dragged stay
/// where they are, and the widget's kind keeps its minimum size inside the grid.
LiveRect liveResizeRect(CellRect o, WidgetKind kind, Set<ResizeSide> sides,
    double dCols, double dRows) {
  var x = o.x.toDouble(), y = o.y.toDouble(), w = o.w.toDouble(), h = o.h.toDouble();
  if (sides.contains(ResizeSide.right)) {
    w = _clampD(o.w + dCols, kind.minW.toDouble(), gridColumns - o.x.toDouble());
  }
  if (sides.contains(ResizeSide.left)) {
    x = _clampD(o.x + dCols, 0, o.x + o.w - kind.minW.toDouble());
    w = o.x + o.w - x;
  }
  if (sides.contains(ResizeSide.bottom)) {
    h = _clampD(o.h + dRows, kind.minH.toDouble(), maxRows.toDouble());
  }
  if (sides.contains(ResizeSide.top)) {
    y = _clampD(o.y + dRows, 0, o.y + o.h - kind.minH.toDouble());
    h = o.y + o.h - y;
  }
  return (x: x, y: y, w: w, h: h);
}

/// Snaps one coordinate to a whole cell. It moves away from [previous] only once the live
/// value is at least 60% of a cell from it, so the target doesn't flicker at a boundary.
int snapCell(double live, int previous) =>
  (live - previous).abs() < 0.6 ? previous : live.round();

/// Snaps a live rectangle to whole cells, keeping it inside the grid.
CellRect snapRect(LiveRect live, CellRect previous) {
  final w = snapCell(live.w, previous.w);
  final h = snapCell(live.h, previous.h);
  return (
    x: within(snapCell(live.x, previous.x), 0, gridColumns - w),
    y: max(0, snapCell(live.y, previous.y)),
    w: w,
    h: h,
  );
}
