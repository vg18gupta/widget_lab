import 'dart:convert';
import 'package:widget_lab/data/layout_repository.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/workspace_store.dart';

/// Turns the layout into saved text and back. The format lives only here.
class LayoutPersistence {
  LayoutPersistence(this._repository);
  final LayoutRepository _repository;

  /// Restores panels, channel symbols and the lock. Returns false if nothing usable was
  /// saved, so the caller can fall back to the default layout.
  Future<bool> read(WorkspaceStore store) async {
    try {
      final raw = await _repository.read();
      if (raw == null) return false;
      final decoded = jsonDecode(raw);
      // Current format is a map; the first version saved a bare list of panels.
      final saved = decoded is Map ? decoded['panels'] as List : decoded as List;
      store.panels
        ..clear()
        ..addAll(saved.map((e) => Panel.fromJson(e)));
      if (decoded is Map) {
        store.locked = decoded['locked'] == true;
        final channels = decoded['channels'];
        if (channels is List) {
          for (var i = 0; i < store.channelSymbols.length && i < channels.length; i++) {
            store.channelSymbols[i].value = channels[i] as String;
          }
        }
      }
      return true; // an empty saved list is a valid layout, not a reason to reset
    } catch (_) {
      store.panels.clear();
      return false;
    }
  }

  Future<void> save(WorkspaceStore store) => _repository.write(jsonEncode({
    'panels': [for (final p in store.panels) p.toJson()],
    'channels': [for (final c in store.channelSymbols) c.value],
    'locked': store.locked,
  }));
}
