import 'dart:math';
import 'package:widget_lab/controller/layout_persistence.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/gesture_preview.dart';
import 'package:widget_lab/store/workspace_store.dart';

/// Every change to the grid: add, move, resize, remove, duplicate, undo, reset and the lock.
/// The rules come from domain/grid_layout.dart. Results go to the store, and each change is
/// saved. Gesture offsets arrive in cells; converting pixels is the presentation's job.
class LayoutController {
  LayoutController(this.store, this.persistence);

  final WorkspaceStore store;
  final LayoutPersistence persistence;

  /// Restores the saved layout, or the default if there is none.
  Future<void> load() async {
    final restored = await persistence.read(store);
    if (!restored) reset(notify: false);
    for (final p in store.panels) {
      if (p.channel >= 0) p.symbol = store.channelSymbols[p.channel].value;
    }
    store.loaded = true;
    store.notifyChanged();
  }

  /// Saves the layout now. Used by the script editor's debounced autosave.
  void persist() => _changed();

  void setLocked(bool value) {
    store.locked = value;
    _changed();
  }

  // ---- Add, remove, duplicate ------------------------------------------------
  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
  int get _bottom => store.panels.fold<int>(0, (v, q) => max(v, q.y + q.h));

  /// Adds a widget at the bottom of the layout (used by the widget menu).
  void add(WidgetKind kind) {
    if (store.locked) return;
    _snapshot();
    store.panels.add(Panel(id: _newId(), kind: kind, x: 0, y: _bottom,
      w: kind.defaultW, h: kind.defaultH));
    settle(store.panels, null);
    _changed();
  }

  /// Adds a widget with its top-left cell at ([x], [y]), as dropped from the hub.
  /// The widget stays where it was dropped; other panels settle around it.
  void addAt(WidgetKind kind, int x, int y) {
    if (store.locked) return;
    _snapshot();
    final p = Panel(id: _newId(), kind: kind,
      x: within(x, 0, gridColumns - kind.defaultW), y: max(0, y),
      w: kind.defaultW, h: kind.defaultH);
    store.panels.add(p);
    settle(store.panels, p);
    _changed();
  }

  void remove(Panel p) {
    if (store.locked) return;
    _snapshot();
    store.panels.removeWhere((e) => e.id == p.id);
    settle(store.panels, null);
    _changed();
  }

  void duplicate(Panel p) {
    if (store.locked) return;
    _snapshot();
    store.panels.add(Panel(id: _newId(), kind: p.kind,
      x: 0, y: _bottom, w: p.w, h: p.h, channel: p.channel, symbol: p.symbol, range: p.range,
      sortBy: p.sortBy, ascending: p.ascending, code: p.code, params: Map.of(p.params)));
    settle(store.panels, null);
    _changed();
  }

  // ---- Drag and resize gestures ----------------------------------------------
  // While the pointer is down the layout doesn't change. The controller works out where
  // everything would land and publishes it as a GesturePreview for the canvas. Releasing
  // the pointer commits that result as one undoable change.
  Panel? _gesturePanel;
  CellRect _origin = (x: 0, y: 0, w: 0, h: 0);
  CellRect _snapped = (x: 0, y: 0, w: 0, h: 0);
  Map<String, CellRect> _cells = {};

  void beginGesture(Panel p) {
    if (store.locked) return;
    _gesturePanel = p;
    _origin = rectOf(p);
    _snapped = _origin;
    _cells = {for (final q in store.panels) q.id: rectOf(q)};
    store.preview.value = GesturePreview(panelId: p.id, live: liveRectOf(_origin), cells: _cells);
  }

  /// Moves the gesture's panel by [dCols] and [dRows] cells from where the gesture began.
  void dragBy(Panel p, double dCols, double dRows) {
    if (!identical(p, _gesturePanel)) return;
    _update(p, liveDragRect(_origin, dCols, dRows));
  }

  /// Resizes the gesture's panel by [dCols] and [dRows] cells on the given [sides].
  void resizeBy(Panel p, Set<ResizeSide> sides, double dCols, double dRows) {
    if (!identical(p, _gesturePanel)) return;
    _update(p, liveResizeRect(_origin, p.kind, sides, dCols, dRows));
  }

  /// Ends the gesture. If anything moved, the result becomes one undoable change.
  void endGesture() {
    final p = _gesturePanel;
    if (p == null) return;
    final moved = _snapped != _origin;
    if (moved) {
      _snapshot();
      for (final q in store.panels) {
        final c = _cells[q.id];
        if (c != null) {
          q.x = c.x; q.y = c.y; q.w = c.w; q.h = c.h;
        }
      }
    }
    _gesturePanel = null;
    _cells = {};
    store.preview.value = null;
    if (moved) _changed();
  }

  void _update(Panel p, LiveRect live) {
    final snapped = snapRect(live, _snapped);
    if (snapped != _snapped) {
      _snapped = snapped;
      _cells = _settledWith(p, snapped);
    }
    store.preview.value = GesturePreview(panelId: p.id, live: live, cells: _cells);
  }

  /// Where every panel would be if [moving] sat at [target]. Works on copies, so the
  /// committed layout is untouched until release.
  Map<String, CellRect> _settledWith(Panel moving, CellRect target) {
    final copies = [for (final q in store.panels) q.copy()];
    final m = copies.firstWhere((c) => c.id == moving.id);
    m.x = target.x; m.y = target.y; m.w = target.w; m.h = target.h;
    settle(copies, m);
    return {for (final c in copies) c.id: rectOf(c)};
  }

  // ---- Full screen, undo, reset ------------------------------------------------
  /// Double-click on a header: full screen if it isn't already, otherwise restores the grid.
  void toggleFullscreen(Panel p) {
    final wasFull = p.fullscreen;
    for (final q in store.panels) {
      q.fullscreen = false;
    }
    p.fullscreen = !wasFull;
    store.notifyChanged();
  }

  void undo() {
    if (store.locked) return;
    final previous = store.popUndo();
    if (previous == null) return;
    store.panels
      ..clear()
      ..addAll(previous.map(Panel.fromJson));
    _changed();
  }

  void reset({bool notify = true}) {
    if (store.locked && notify) return; // a user's reset is refused; load() passes notify:false
    store.panels
      ..clear()
      ..addAll(defaultLayout());
    if (notify) _changed();
  }

  // ---- Internals ---------------------------------------------------------------
  void _snapshot() => store.pushUndo(store.snapshot());

  void _changed() {
    store.notifyChanged();
    persistence.save(store);
  }
}
