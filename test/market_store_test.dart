import 'package:flutter_test/flutter_test.dart';
import 'package:widget_lab/store/market_store.dart';

void main() {
  test('chart windows are capped to maxChartPoints', () {
    final m = MarketStore();
    for (final range in ['1m', '5m', '15m']) {
      expect(m.history('AAA', range).length,
        lessThanOrEqualTo(MarketStore.maxChartPoints), reason: range);
    }
  });

  test('the 1m window covers about one minute of time', () {
    final first = MarketStore().history('AAA', '1m').first.time;
    final ageMinutes = DateTime.now().difference(first).inSeconds / 60;
    expect(ageMinutes, inInclusiveRange(0.9, 1.1));
  });

  test('the 5m window covers about five minutes of time', () {
    final first = MarketStore().history('AAA', '5m').first.time;
    final ageMinutes = DateTime.now().difference(first).inSeconds / 60;
    expect(ageMinutes, inInclusiveRange(4.9, 5.1));
  });

  test('the 15m window covers about fifteen minutes of time', () {
    final first = MarketStore().history('AAA', '15m').first.time;
    final ageMinutes = DateTime.now().difference(first).inSeconds / 60;
    expect(ageMinutes, inInclusiveRange(14.9, 15.1));
  });

  test('a window always ends with the newest tick', () {
    final m = MarketStore();
    expect(m.history('BBB', '15m').last, same(m.latest('BBB')));
  });
}
