import 'dart:collection';
import 'package:flutter/scheduler.dart';

/// Rolling average of recent frame times. Tells the charts when frames are running over
/// budget, so that they should batch their redraws instead of drawing on every tick.
///
/// Uses hysteresis: it goes over budget when the average exceeds [budget], and only
/// comes back under once the average falls below 75% of it. This stops the mode from
/// flickering on and off around the threshold.
class FrameBudget {
  FrameBudget({this.budget = const Duration(milliseconds: 16), this.window = 10});

  /// The app-wide instance, fed by Flutter's frame timings once [attach] is called.
  static final FrameBudget instance = FrameBudget();

  final Duration budget;
  final int window;
  final _recent = ListQueue<Duration>();
  bool _over = false;
  TimingsCallback? _callback;

  /// Starts receiving frame timings from the engine.
  void attach() {
    if (_callback != null) return;
    _callback = (timings) {
      for (final t in timings) {
        record(t.totalSpan);
      }
    };
    SchedulerBinding.instance.addTimingsCallback(_callback!);
  }

  void detach() {
    final callback = _callback;
    if (callback == null) return;
    SchedulerBinding.instance.removeTimingsCallback(callback);
    _callback = null;
  }

  /// Adds one frame's total time. Public so tests can feed frame times directly.
  void record(Duration frame) {
    _recent.addLast(frame);
    if (_recent.length > window) _recent.removeFirst();
    if (_recent.length < window) return;
    final average = _recent.fold<int>(0, (sum, d) => sum + d.inMicroseconds) / window;
    if (!_over && average > budget.inMicroseconds) {
      _over = true;
    } else if (_over && average < budget.inMicroseconds * 0.75) {
      _over = false;
    }
  }

  /// True while recent frames are running over budget.
  bool get overBudget => _over;

  /// Forgets all recorded frames. Used by tests.
  void reset() {
    _recent.clear();
    _over = false;
  }
}
