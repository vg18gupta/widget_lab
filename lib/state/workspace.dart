import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:widget_lab/market/market_store.dart';
import 'package:widget_lab/models/constants.dart';
import 'package:widget_lab/models/panel.dart';

/// The edges of a widget that a resize gesture moves. Corners use two sides.
enum ResizeSide { left, right, top, bottom }

class Workspace extends ChangeNotifier {
  Workspace(this.market);
  final MarketStore market;
  final List<Panel> panels = [];
  final List<List<Map<String,dynamic>>> _undo = [];
  final List<ValueNotifier<String>> channelSymbols =
    List.generate(4, (_) => ValueNotifier<String>('AAA'));
  bool narrow = false;
  /// False until the saved layout has been read from storage.
  bool loaded = false;
  bool _locked = false;
  /// When locked, every layout change is refused. Channels, symbols and full screen still work.
  bool get locked => _locked;
  void setLocked(bool value) { _locked = value; _changed(); }
  static const _key = 'widget_lab_layout_v1';
  static const _columns = 12;

  Future<void> load() async {
    var restored = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        // Current format is a map; the first version saved a bare list of panels.
        final saved = decoded is Map ? decoded['panels'] as List : decoded as List;
        panels
          ..clear()
          ..addAll(saved.map((e) => Panel.fromJson(e)));
        if (decoded is Map) _locked = decoded['locked'] == true;
        if (decoded is Map && decoded['channels'] is List) {
          final channels = decoded['channels'] as List;
          for (var i = 0; i < channelSymbols.length && i < channels.length; i++) {
            channelSymbols[i].value = channels[i] as String;
          }
        }
        restored = true; // an empty saved list is a valid layout, not a reason to reset
      }
    } catch (_) {
      panels.clear();
    }
    if (!restored) reset(notify: false);
    for (final p in panels) {
      if (p.channel >= 0) p.symbol = channelSymbols[p.channel].value;
    }
    loaded = true;
    notifyListeners();
  }
  void _snapshot() {
    _undo.add(panels.map((p) => p.toJson()).toList());
    if (_undo.length > 30) _undo.removeAt(0);
  }
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      'panels': panels.map((p)=>p.toJson()).toList(),
      'channels': [for (final c in channelSymbols) c.value],
      'locked': _locked,
    }));
  }
  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
  /// Y coordinate just below the lowest panel.
  int get _bottom => panels.fold<int>(0, (v, q) => max(v, q.y + q.h));
  /// [v] limited to [lo]..[hi]. Unlike `clamp`, never throws if the bounds conflict.
  int _within(int v, int lo, int hi) => min(max(v, lo), max(lo, hi));

  /// Adds a widget at the bottom of the layout (used by the widget menu).
  void add(WidgetKind kind) {
    if (_locked) return;
    _snapshot();
    panels.add(Panel(id: _newId(), kind: kind, x: 0, y: _bottom,
      w: kind.defaultW, h: kind.defaultH));
    _settle(panels, null);
    _changed();
  }

  /// Adds a widget with its top-left cell at ([x], [y]), as dropped from the hub.
  /// The widget stays where it was dropped; other panels settle around it.
  void addAt(WidgetKind kind, int x, int y) {
    if (_locked) return;
    _snapshot();
    final p = Panel(id: _newId(), kind: kind,
      x: _within(x, 0, _columns - kind.defaultW), y: max(0, y),
      w: kind.defaultW, h: kind.defaultH);
    panels.add(p);
    _settle(panels, p);
    _changed();
  }

  // ---- Layout -------------------------------------------------------------
  /// Tidy layout. [fixed] keeps its exact cell. Every other panel is placed in turn,
  /// top to bottom, in the highest free row that doesn't overlap a panel already placed.
  /// So panels move aside for [fixed], return when it moves away, and gaps close.
  static void _settle(List<Panel> items, Panel? fixed) {
    final placed = <Panel>[if (fixed != null) fixed];
    final rest = items.where((q) => !identical(q, fixed)).toList()
      ..sort((a, b) => a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x));
    for (final q in rest) {
      q.y = 0;
      while (placed.any((f) => _overlaps(q, f))) {
        q.y++;
      }
      placed.add(q);
    }
  }

  static bool _overlaps(Panel a, Panel b) =>
    a.x < b.x + b.w && a.x + a.w > b.x && a.y < b.y + b.h && a.y + a.h > b.y;

  // ---- Drag and resize gestures ------------------------------------------
  // Pointer offsets are measured from the gesture's start, so sub-cell movements
  // accumulate. Each update re-lays out the grid from the start positions, so the
  // result depends only on where the pointer is now. The layout is snapshotted once
  // (on the first real change, so undo reverts a whole gesture) and saved on release.
  Panel? _gesturePanel;
  Map<String, ({int x, int y, int w, int h})> _origins = {};
  bool _gestureSnapshotted = false;

  void beginGesture(Panel p) {
    if (_locked) return;
    _gesturePanel = p;
    _origins = {for (final q in panels) q.id: (x: q.x, y: q.y, w: q.w, h: q.h)};
    _gestureSnapshotted = false;
  }

  /// Moves the gesture's panel to its start cell plus [totalDx]/[totalDy] pixels.
  void dragBy(Panel p, double totalDx, double totalDy, double cellW) {
    if (!identical(p, _gesturePanel)) return;
    final o = _origins[p.id]!;
    _relayout(p,
      _within(o.x + (totalDx / cellW).round(), 0, _columns - o.w),
      max(0, o.y + (totalDy / rowHeight).round()),
      o.w, o.h);
  }

  /// Resizes the gesture's panel by [totalDx]/[totalDy] pixels on the given [sides].
  /// The opposite edges stay where they are, and each kind's minimum size is kept.
  void resizeBy(Panel p, Set<ResizeSide> sides, double totalDx, double totalDy, double cellW) {
    if (!identical(p, _gesturePanel)) return;
    final o = _origins[p.id]!;
    final dc = (totalDx / cellW).round();
    final dr = (totalDy / rowHeight).round();
    var x = o.x, y = o.y, w = o.w, h = o.h;
    if (sides.contains(ResizeSide.right)) {
      w = _within(o.w + dc, p.kind.minW, _columns - o.x);
    }
    if (sides.contains(ResizeSide.left)) {
      x = _within(o.x + dc, 0, o.x + o.w - p.kind.minW);
      w = o.x + o.w - x;
    }
    if (sides.contains(ResizeSide.bottom)) {
      h = _within(o.h + dr, p.kind.minH, 12);
    }
    if (sides.contains(ResizeSide.top)) {
      y = _within(o.y + dr, 0, o.y + o.h - p.kind.minH);
      h = o.y + o.h - y;
    }
    _relayout(p, x, y, w, h);
  }

  void endGesture() {
    if (_gestureSnapshotted) _save();
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
    for (final q in panels) {
      final o = _origins[q.id]!;
      q.x = o.x; q.y = o.y; q.w = o.w; q.h = o.h;
    }
    moving.x = x; moving.y = y; moving.w = w; moving.h = h;
    _settle(panels, moving);
    notifyListeners();
  }

  // ---- Full screen ----------------------------------------------------------
  /// The panel shown full screen, or null when the grid is showing.
  Panel? get fullscreenPanel {
    for (final p in panels) {
      if (p.fullscreen) return p;
    }
    return null;
  }
  /// Double-click on a header: full screen if it isn't already, otherwise restores the grid.
  void toggleFullscreen(Panel p) {
    final wasFull = p.fullscreen;
    for (final q in panels) {
      q.fullscreen = false;
    }
    p.fullscreen = !wasFull;
    notifyListeners();
  }

  // ---- Remove, duplicate, undo, reset -------------------------------------
  void remove(Panel p) {
    if (_locked) return;
    _snapshot();
    panels.removeWhere((e)=>e.id==p.id);
    _settle(panels, null);
    _changed();
  }
  void duplicate(Panel p) {
    if (_locked) return;
    _snapshot();
    panels.add(Panel(id:_newId(),kind:p.kind,
      x:0,y:_bottom,w:p.w,h:p.h,channel:p.channel,symbol:p.symbol,range:p.range,
      sortBy:p.sortBy,ascending:p.ascending,code:p.code,params:Map.of(p.params)));
    _settle(panels, null);
    _changed();
  }
  void undo() {
    if (_locked || _undo.isEmpty) return;
    panels
      ..clear()
      ..addAll(_undo.removeLast().map(Panel.fromJson));
    _changed();
  }
  void reset({bool notify=true}) {
    if (_locked && notify) return; // user-initiated reset is refused; load() passes notify:false
    panels
      ..clear()
      ..add(Panel(id:'default-chart',kind:WidgetKind.chart,x:0,y:0,w:4,h:7))
      ..add(Panel(id:'default-table',kind:WidgetKind.table,x:4,y:0,w:4,h:7))
      ..add(Panel(id:'default-script',kind:WidgetKind.script,x:8,y:0,w:4,h:7));
    if (notify) _changed();
  }

  // ---- Linking and settings -------------------------------------------------
  /// Links [p] to [channel] (or unlinks with -1). A widget joining a channel with
  /// other members takes the channel's symbol. A widget joining an empty channel
  /// sets the channel's symbol to its own. Unlinking keeps the last symbol.
  void setChannel(Panel p, int channel) {
    p.channel=channel;
    if (channel>=0) {
      final hasMembers = panels.any((q) => !identical(q, p) && q.channel == channel);
      if (hasMembers) {
        p.symbol=channelSymbols[channel].value;
      } else {
        channelSymbols[channel].value=p.symbol;
      }
    }
    _changed();
  }
  /// Changes the symbol for [p]: the whole channel if linked, otherwise just [p].
  void selectSymbol(Panel p, String symbol) {
    if (p.channel>=0) {
      channelSymbols[p.channel].value=symbol;
      for (final linked in panels.where((e)=>e.channel==p.channel)) linked.symbol=symbol;
    } else { p.symbol=symbol; }
    _changed();
  }
  /// Stores one script setting and saves it with the layout.
  void setParam(Panel p, String name, double value) {
    p.params = {...p.params, name: value};
    _changed();
  }
  void _changed() { notifyListeners(); _save(); }
  /// Persists the current layout (used by the script editor's debounced autosave).
  void persist() => _changed();
  @override void dispose() { for (final c in channelSymbols) { c.dispose(); } super.dispose(); }
}
