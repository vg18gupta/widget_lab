import 'dart:math';
import 'package:widget_lab/domain/panel.dart';

/// Pure grid rules. Everything here works in cells, never pixels.

/// Number of columns in the grid.
const gridColumns = 12;

/// Largest height a widget can be resized to, in rows.
const maxRows = 12;

/// A rectangle in grid cells.
typedef CellRect = ({int x, int y, int w, int h});

/// The edges a resize gesture moves. Corners use two sides.
enum ResizeSide { left, right, top, bottom }

CellRect rectOf(Panel p) => (x: p.x, y: p.y, w: p.w, h: p.h);

/// The layout a new user starts with: a chart, a table and a script across the top.
List<Panel> defaultLayout() => [
  Panel(id: 'default-chart', kind: WidgetKind.chart, x: 0, y: 0, w: 4, h: 7),
  Panel(id: 'default-table', kind: WidgetKind.table, x: 4, y: 0, w: 4, h: 7),
  Panel(id: 'default-script', kind: WidgetKind.script, x: 8, y: 0, w: 4, h: 7),
];

/// [v] limited to [lo]..[hi]. Unlike `clamp`, never throws if the bounds conflict.
int within(int v, int lo, int hi) => min(max(v, lo), max(lo, hi));

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

/// Where a dragged widget ends up, given where it started and the cell offset moved.
/// It stays inside the grid and above the top row.
({int x, int y}) dragTarget(CellRect origin, int dCols, int dRows) => (
  x: within(origin.x + dCols, 0, gridColumns - origin.w),
  y: max(0, origin.y + dRows),
);

/// The rectangle a resized widget ends up with. The edges that aren't being dragged stay
/// where they are, and the widget's kind keeps its minimum size and stays inside the grid.
CellRect resizeTarget(CellRect origin, WidgetKind kind, Set<ResizeSide> sides,
    int dCols, int dRows) {
  var x = origin.x, y = origin.y, w = origin.w, h = origin.h;
  if (sides.contains(ResizeSide.right)) {
    w = within(origin.w + dCols, kind.minW, gridColumns - origin.x);
  }
  if (sides.contains(ResizeSide.left)) {
    x = within(origin.x + dCols, 0, origin.x + origin.w - kind.minW);
    w = origin.x + origin.w - x;
  }
  if (sides.contains(ResizeSide.bottom)) {
    h = within(origin.h + dRows, kind.minH, maxRows);
  }
  if (sides.contains(ResizeSide.top)) {
    y = within(origin.y + dRows, 0, origin.y + origin.h - kind.minH);
    h = origin.y + origin.h - y;
  }
  return (x: x, y: y, w: w, h: h);
}
