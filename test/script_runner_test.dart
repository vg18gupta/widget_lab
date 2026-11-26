import 'package:flutter_test/flutter_test.dart';
import 'package:widget_lab/domain/script_runner.dart';

void main() {
  test('parseParams reads a declaration', () {
    final ps = parseParams('param threshold: 10 [0..100]\nreturn {};');
    expect(ps.length, 1);
    expect(ps.single.name, 'threshold');
    expect(ps.single.defaultValue, 10);
    expect(ps.single.min, 0);
    expect(ps.single.max, 100);
  });

  test('parseParams ignores a declaration with an empty range', () {
    expect(parseParams('param x: 5 [10..10]'), isEmpty);
  });

  test('a value can reference a declared param', () {
    final out = runScript('param t: 10 [0..100]\nlabel: "Spread"\nvalue: t',
      (_) => 0.0, {'t': 42});
    expect(out['type'], 'stat');
    expect(out['label'], 'Spread');
    expect(out['value'], 42.0);
  });

  test('a numeric value literal is used as given', () {
    final out = runScript('label: "Spread"\nvalue: 12.4', (_) => 0.0, {});
    expect(out['value'], 12.4);
  });

  test('an unknown name in value throws a FormatException', () {
    expect(() => runScript('value: nope', (_) => 0.0, {}),
      throwsA(isA<FormatException>()));
  });

  test('a script without a value field throws a FormatException', () {
    expect(() => runScript('label: "x"', (_) => 0.0, {}),
      throwsA(isA<FormatException>()));
  });

  test('an empty script throws a FormatException', () {
    expect(() => runScript('   ', (_) => 0.0, {}),
      throwsA(isA<FormatException>()));
  });
}
