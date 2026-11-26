import 'package:flutter/foundation.dart';
import 'package:widget_lab/domain/panel.dart';

/// The layout's state: panels, channel symbols, the lock and the undo history. It holds
/// data and notifies listeners. Controllers make the changes, and nothing here touches
/// storage or pixels.
class WorkspaceStore extends ChangeNotifier {
  final List<Panel> panels = [];
  final List<ValueNotifier<String>> channelSymbols =
    List.generate(4, (_) => ValueNotifier<String>('AAA'));
  /// False until the saved layout has been read.
  bool loaded = false;
  /// When true, controllers refuse layout changes.
  bool locked = false;

  final List<List<Map<String, dynamic>>> _undo = [];
  static const _undoLimit = 30;

  /// The panel shown full screen, or null when the grid is showing.
  Panel? get fullscreenPanel {
    for (final p in panels) {
      if (p.fullscreen) return p;
    }
    return null;
  }

  /// The current layout as plain data, for the undo history and for saving.
  List<Map<String, dynamic>> snapshot() => [for (final p in panels) p.toJson()];

  bool get canUndo => _undo.isNotEmpty;
  void pushUndo(List<Map<String, dynamic>> snapshot) {
    _undo.add(snapshot);
    if (_undo.length > _undoLimit) _undo.removeAt(0);
  }
  /// The most recent snapshot, removed from the history, or null if there is none.
  List<Map<String, dynamic>>? popUndo() => _undo.isEmpty ? null : _undo.removeLast();

  void notifyChanged() => notifyListeners();

  @override
  void dispose() {
    for (final c in channelSymbols) {
      c.dispose();
    }
    super.dispose();
  }
}
