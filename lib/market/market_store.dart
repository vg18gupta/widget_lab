import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:widget_lab/models/constants.dart';
import 'package:widget_lab/models/tick.dart';

class MarketStore {
  /// Longest chart window. Older ticks are dropped.
  static const retention = Duration(minutes: 15);
  /// Charts and tables are downsampled to at most this many points.
  static const maxChartPoints = 300;
  /// Seeded history: one tick per second across the full retention window.
  static const _seedSeconds = 15 * 60;

  MarketStore({int seed = 42}) : _random = Random(seed), seed = seed {
    final now = DateTime.now();
    for (final s in symbols) {
      final base = 80 + symbols.indexOf(s) * 35.0;
      var value = base;
      final history = <Tick>[];
      for (var i = 0; i < _seedSeconds; i++) {
        value += (_random.nextDouble() - .5) * 1.2;
        history.add(Tick(now.subtract(Duration(seconds: _seedSeconds - i)), value));
      }
      _history[s] = history;
      _latest[s] = ValueNotifier<Tick>(history.last);
    }
  }
  Random _random;
  Timer? _timer;
  final Map<String,List<Tick>> _history = {};
  final Map<String,ValueNotifier<Tick>> _latest = {};
  /// Fires once per feed tick, after every symbol has updated. Widgets that need every
  /// symbol subscribe here rather than to each symbol, so they rebuild once per tick.
  final ValueNotifier<int> batch = ValueNotifier<int>(0);
  bool paused = false, dropped = false;
  int intervalMs = 150, seed = 42;
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

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (paused || dropped) return;
      final now = DateTime.now();
      final cutoff = now.subtract(retention);
      for (final s in symbols) {
        final old = latest(s);
        final next = old.value + (_random.nextDouble() - .49) * 1.1;
        final tick = Tick(now, next);
        final history = _history[s]!..add(tick);
        while (history.length > 1 && history.first.time.isBefore(cutoff)) {
          history.removeAt(0);
        }
        _latest[s]!.value = tick;
      }
      batch.value++;
    });
  }
  void configure({bool? pause, bool? drop, int? rate, int? newSeed}) {
    if (pause != null) paused = pause;
    if (drop != null) dropped = drop;
    if (rate != null) intervalMs = rate;
    if (newSeed != null) {
      seed = newSeed;
      _random = Random(seed);
    }
    start();
  }
  void dispose() { _timer?.cancel(); batch.dispose(); for (final n in _latest.values) { n.dispose(); } }
}
