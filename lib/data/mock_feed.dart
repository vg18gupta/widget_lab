import 'dart:async';
import 'dart:math';
import 'package:widget_lab/config/constants.dart';
import 'package:widget_lab/domain/tick.dart';

/// The simulated market: a seeded random walk per symbol. The same seed gives the same
/// values. The feed produces prices and knows nothing about storage or widgets. It hands
/// each tick to [onTick], and the store decides what to keep.
class MockFeed {
  MockFeed({int seed = 42, required this.onTick})
      : _random = Random(seed),
        seed = seed;

  /// One-second history generated per symbol: the full 15-minute window.
  static const seedSeconds = 15 * 60;

  /// Called on each tick with the time and every symbol's new price.
  final void Function(DateTime now, Map<String, double> prices) onTick;

  Random _random;
  Timer? _timer;
  final Map<String, double> _last = {};
  bool paused = false, dropped = false;
  int intervalMs = 150;
  int seed;

  /// Generates [seedSeconds] of history per symbol, ending at [now]. Call this once, before
  /// [start], so the random sequence starts from the seed.
  Map<String, List<Tick>> seedHistory(DateTime now) {
    final out = <String, List<Tick>>{};
    for (final s in symbols) {
      var value = 80 + symbols.indexOf(s) * 35.0;
      final history = <Tick>[];
      for (var i = 0; i < seedSeconds; i++) {
        value += (_random.nextDouble() - .5) * 1.2;
        history.add(Tick(now.subtract(Duration(seconds: seedSeconds - i)), value));
      }
      out[s] = history;
      _last[s] = value;
    }
    return out;
  }

  /// Starts emitting ticks at [intervalMs]. Ticks are skipped while paused or dropped.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (paused || dropped) return;
      final now = DateTime.now();
      final prices = <String, double>{};
      for (final s in symbols) {
        final next = _last[s]! + (_random.nextDouble() - .49) * 1.1;
        _last[s] = next;
        prices[s] = next;
      }
      onTick(now, prices);
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

  void dispose() => _timer?.cancel();
}
