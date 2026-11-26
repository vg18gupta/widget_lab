import 'package:widget_lab/config/constants.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/store/market_store.dart';

/// One table row: a symbol's last price and its change over the table's window.
class TableRowData {
  const TableRowData(this.symbol, this.last, this.change, this.pct);
  final String symbol;
  final double last, change, pct;
}

/// Builds the table's rows from the market and the panel's sort settings.
class TableController {
  /// The window the change column is measured over.
  static const window = '15m';

  /// Rows for the symbols with data, sorted by the panel's column. Null while no symbol has
  /// data yet (loading). Empty if data exists but none is inside the window.
  List<TableRowData>? rows(MarketStore market, Panel panel) {
    if (!symbols.any(market.hasData)) return null;
    final rows = <TableRowData>[];
    for (final s in symbols) {
      final h = market.history(s, window);
      if (h.isEmpty) continue;
      final last = h.last.value, first = h.first.value;
      rows.add(TableRowData(s, last, last - first, first == 0 ? 0 : (last - first) / first * 100));
    }
    rows.sort((a, b) {
      final c = _sortKey(a, panel.sortBy).compareTo(_sortKey(b, panel.sortBy));
      return panel.ascending ? c : -c;
    });
    return rows;
  }

  Comparable<dynamic> _sortKey(TableRowData r, String column) {
    if (column == 'last') return r.last;
    if (column == 'change') return r.change;
    if (column == 'pct') return r.pct;
    return r.symbol;
  }

  /// A header click sorts on that column; clicking the same column again reverses it.
  void toggleSort(Panel panel, String column) {
    if (panel.sortBy == column) {
      panel.ascending = !panel.ascending;
    } else {
      panel.sortBy = column;
      panel.ascending = true;
    }
  }
}
