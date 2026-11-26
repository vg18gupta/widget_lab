enum WidgetKind { chart, table, script }

/// Grid sizes in cells for each widget kind.
extension WidgetKindLayout on WidgetKind {
  /// Size used when a widget is added.
  int get defaultW => switch (this) { WidgetKind.chart => 3, _ => 4 };
  int get defaultH => switch (this) { WidgetKind.script => 5, _ => 6 };
  /// Smallest size a widget can be resized to. Chosen so its content still fits.
  int get minW => switch (this) { WidgetKind.chart => 3, _ => 4 };
  int get minH => switch (this) { WidgetKind.script => 5, _ => 3 };
}

class Panel {
  Panel({required this.id, required this.kind, this.x = 0, this.y = 0,
    this.w = 4, this.h = 5, this.channel = -1, this.symbol = 'AAA',
    this.range = '1m', this.sortBy = 'symbol', this.ascending = true,
    this.code = 'return { type: \"stat\", label: \"Spread\", value: 12.4 };',
    this.fullscreen = false, Map<String, double>? params})
    : params = params ?? {};
  final String id;
  final WidgetKind kind;
  int x, y, w, h, channel;
  String symbol, range, sortBy, code;
  bool ascending, fullscreen;
  /// Current values of the script's `param` settings, keyed by parameter name.
  /// Replaced rather than mutated, so undo snapshots stay correct.
  Map<String, double> params;
  Map<String, dynamic> toJson() => {'id':id,'kind':kind.name,'x':x,'y':y,'w':w,'h':h,
    'channel':channel,'symbol':symbol,'range':range,'sortBy':sortBy,'ascending':ascending,'code':code,
    'params':Map<String,double>.of(params)};
  factory Panel.fromJson(Map<String,dynamic> j) => Panel(
    id:j['id'], kind:WidgetKind.values.byName(j['kind']), x:j['x'], y:j['y'],
    w:j['w'], h:j['h'], channel:j['channel'] ?? -1, symbol:j['symbol'] ?? 'AAA',
    range:j['range'] ?? '1m', sortBy:j['sortBy'] ?? 'symbol',
    ascending:j['ascending'] ?? true, code:j['code'] ?? '',
    params:(j['params'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())));
  Panel copy() => Panel.fromJson(toJson());
}
