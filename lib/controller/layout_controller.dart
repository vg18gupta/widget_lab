import 'dart:math';
import 'package:widget_lab/controller/layout_persistence.dart';
import 'package:widget_lab/domain/grid_layout.dart';
import 'package:widget_lab/domain/panel.dart';
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
  // Each update lays out the grid again from the gesture's start, so the result depends
  // only on the offset now. The layout is snapshotted once (on the first real change, so
  // undo reverts a whole gesture) and saved on release.
  Panel? _gesturePanel;
  Map<String, CellRect> _origins = {};
  bool _gestureSnapshotted = false;

  void beginGesture(Panel p) {
    if (store.locked) return;
    _gesturePanel = p;
    _origins = {for (final q in store.panels) q.id: rectOf(q)};
    _gestureSnapshotted = false;
  }

  /// Moves the gesture's panel by [dCols] and [dRows] cells from where the gesture began.
  void dragBy(Panel p, int dCols, int dRows) {
    if (!identical(p, _gesturePanel)) return;
    final o = _origins[p.id]!;
    final t = dragTarget(o, dCols, dRows);
    _relayout(p, t.x, t.y, o.w, o.h);
  }

  /// Resizes the gesture's panel by [dCols] and [dRows] cells on the given [sides].
  void resizeBy(Panel p, Set<ResizeSide> sides, int dCols, int dRows) {
    if (!identical(p, _gesturePanel)) return;
    final o = _origins[p.id]!;
    final r = resizeTarget(o, p.kind, sides, dCols, dRows);
    _relayout(p, r.x, r.y, r.w, r.h);
  }

  void endGesture() {
    if (_gestureSnapshotted) _changed();
    _gesturePanel = null;
    _origins = {};
    _gestureSnapshotted = false;
  }

  void _relayout(Panel moving, int x, int y, int w, int h) {
    if (moving.x == x && moving.y == y && moving.w == w && moving.h == h) return;
    if (!_gestureSnapshotted) {
      // Nothing has changed yet in this gesture, so the current layout is the original.
      _snapshot();
      _gestureSnapshotted = true;
    }
    for (final q in store.panels) {
      final o = _origins[q.id]!;
      q.x = o.x; q.y = o.y; q.w = o.w; q.h = o.h;
    }
    moving.x = x; moving.y = y; moving.w = w; moving.h = h;
    settle(store.panels, moving);
    store.notifyChanged();
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
