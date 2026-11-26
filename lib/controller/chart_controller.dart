import 'dart:math';
import 'package:widget_lab/config/constants.dart';
import 'package:widget_lab/data/frame_budget.dart';
import 'package:widget_lab/store/market_store.dart';

/// A chart's data: x in seconds from [start], y the price. Plain numbers, no drawing types.
class ChartSeries {
  ChartSeries(this.start, this.points, this.minY, this.maxY);
  final DateTime start;
  final List<({double x, double y})> points;
  final double minY, maxY;
  /// Seconds across the chart, at least one so the axis always has a length.
  double get span => max(points.last.x, 1.0);
}

/// Shapes the market history into chart data.
class ChartController {
  /// The series for [symbol] over [range], or null if no ticks are inside the window.
  ChartSeries? series(MarketStore market, String symbol, String range) {
    final pts = market.history(symbol, range);
    if (pts.isEmpty) return null;
    final start = pts.first.time;
    final points = [
      for (final t in pts) (x: t.time.difference(start).inMilliseconds / 1000, y: t.value),
    ];
    final ys = pts.map((t) => t.value);
    return ChartSeries(start, points, ys.reduce(min) - 1, ys.reduce(max) + 1);
  }
}

/// Decides when a live chart may redraw. A tick that comes too soon is skipped, and the
/// presentation schedules a catch-up redraw for when the interval ends.
///
/// The interval is the user's setting, or the batching interval while frames are over
/// budget, whichever is longer.
class RedrawGate {
  RedrawGate({FrameBudget? frames}) : _frames = frames ?? FrameBudget.instance;

  final FrameBudget _frames;
  DateTime? _lastDraw;
  String? _lastKey;
  bool _due = false;

  Duration get interval {
    if (adaptiveChartBatching && _frames.overBudget && batchedChartInterval > chartRedrawInterval) {
      return batchedChartInterval;
    }
    return chartRedrawInterval;
  }

  /// True if the chart should draw now for [key] (symbol and range). A true result is
  /// recorded as the last draw.
  bool shouldDraw(String key, DateTime now) {
    final wait = interval;
    if (_due || wait == Duration.zero || _lastDraw == null || _lastKey != key ||
        now.difference(_lastDraw!) >= wait) {
      _due = false;
      _lastDraw = now;
      _lastKey = key;
      return true;
    }
    return false;
  }

  /// How long after the last draw the next one is allowed. Call after [shouldDraw] said no.
  Duration waitFrom(DateTime now) => interval - now.difference(_lastDraw!);

  /// Marks a skipped redraw as due, so the next [shouldDraw] returns true.
  void markDue() => _due = true;
}
