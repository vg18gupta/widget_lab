import 'package:flutter/foundation.dart';
import 'package:widget_lab/config/constants.dart';
import 'package:widget_lab/data/mock_feed.dart';
import 'package:widget_lab/domain/tick.dart';

/// Keeps the market's history and latest prices. Prices come from the [MockFeed]; widgets
/// read them here. The store also keeps the shared windows of history that charts draw.
class MarketStore {
  /// Longest window kept. Older ticks are dropped.
  static const retention = Duration(minutes: 15);
  /// Charts and tables are downsampled to at most this many points.
  static const maxChartPoints = 300;

  MarketStore({int seed = 42}) {
    feed = MockFeed(seed: seed, onTick: _ingest);
    final seeded = feed.seedHistory(DateTime.now());
    for (final s in symbols) {
      _history[s] = seeded[s]!;
      _latest[s] = ValueNotifier<Tick>(seeded[s]!.last);
    }
  }

  late final MockFeed feed;
  final Map<String, List<Tick>> _history = {};
  final Map<String, ValueNotifier<Tick>> _latest = {};
  /// Fires once per feed tick, after every symbol has updated. Widgets that need every
  /// symbol subscribe here rather than to each symbol, so they rebuild once per tick.
  final ValueNotifier<int> batch = ValueNotifier<int>(0);

  ValueListenable<Tick> listen(String s) => _latest[s]!;
  Tick latest(String s) => _latest[s]!.value;
  /// False until the symbol has at least one tick, so widgets can show a loading state.
  bool hasData(String s) => _history[s]?.isNotEmpty ?? false;

  static Duration rangeDuration(String range) => switch (range) {
    '1m' => const Duration(minutes: 1),
    '5m' => const Duration(minutes: 5),
    _ => const Duration(minutes: 15),
  };

  // Every chart on a symbol and range needs the same window until the next tick, so each
  // window is computed once per tick and shared. Windows are read-only; callers must not
  // modify the list.
  final Map<String, List<Tick>> _windows = {};
  int _windowsTick = -1;

  /// Ticks from the last [range] window, downsampled to at most [maxChartPoints].
  /// The newest tick is always included. Empty if nothing arrived inside the window.
  List<Tick> history(String s, String range) {
    if (_windowsTick != batch.value) {
      _windows.clear();
      _windowsTick = batch.value;
    }
    return _windows.putIfAbsent('$s|$range', () => _window(s, range));
  }

  List<Tick> _window(String s, String range) {
    final all = _history[s]!;
    final from = _firstAtOrAfter(all, DateTime.now().subtract(rangeDuration(range)));
    final window = all.sublist(from);
    if (window.length <= maxChartPoints) return window;
    final stride = (window.length / maxChartPoints).ceil();
    final picked = <Tick>[for (var i = window.length - 1; i >= 0; i -= stride) window[i]];
    return picked.reversed.toList();
  }

  /// Index of the first tick at or after [t]. Ticks are stored in time order.
  static int _firstAtOrAfter(List<Tick> ticks, DateTime t) {
    var lo = 0, hi = ticks.length;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (ticks[mid].time.isBefore(t)) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// Receives one feed tick: appends it to each symbol's history, drops what is older than
  /// the retention window, updates the latest price, and fires [batch].
  void _ingest(DateTime now, Map<String, double> prices) {
    final cutoff = now.subtract(retention);
    for (final s in symbols) {
      final tick = Tick(now, prices[s]!);
      final history = _history[s]!..add(tick);
      while (history.length > 1 && history.first.time.isBefore(cutoff)) {
        history.removeAt(0);
      }
      _latest[s]!.value = tick;
    }
    batch.value++;
  }

  // Feed controls, passed through so the dev strip has one place to call.
  bool get paused => feed.paused;
  bool get dropped => feed.dropped;
  int get intervalMs => feed.intervalMs;
  int get seed => feed.seed;
  void start() => feed.start();
  void configure({bool? pause, bool? drop, int? rate, int? newSeed}) =>
    feed.configure(pause: pause, drop: drop, rate: rate, newSeed: newSeed);

  void dispose() {
    feed.dispose();
    batch.dispose();
    for (final n in _latest.values) {
      n.dispose();
    }
  }
}
