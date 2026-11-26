import 'package:widget_lab/controller/layout_persistence.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/workspace_store.dart';

/// Links widgets to the four colour channels and changes the symbol they share.
class ChannelController {
  ChannelController(this.store, this.persistence);

  final WorkspaceStore store;
  final LayoutPersistence persistence;

  /// Links [p] to [channel] (or unlinks with -1). A widget joining a channel with other
  /// members takes the channel's symbol. A widget joining an empty channel sets the
  /// channel's symbol to its own. Unlinking keeps the last symbol.
  void setChannel(Panel p, int channel) {
    p.channel = channel;
    if (channel >= 0) {
      final hasMembers = store.panels.any((q) => !identical(q, p) && q.channel == channel);
      if (hasMembers) {
        p.symbol = store.channelSymbols[channel].value;
      } else {
        store.channelSymbols[channel].value = p.symbol;
      }
    }
    _changed();
  }

  /// Changes the symbol for [p]: the whole channel if linked, otherwise just [p].
  void selectSymbol(Panel p, String symbol) {
    if (p.channel >= 0) {
      store.channelSymbols[p.channel].value = symbol;
      for (final linked in store.panels.where((e) => e.channel == p.channel)) {
        linked.symbol = symbol;
      }
    } else {
      p.symbol = symbol;
    }
    _changed();
  }

  void _changed() {
    store.notifyChanged();
    persistence.save(store);
  }
}
