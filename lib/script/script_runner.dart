import 'package:tradl_widget_lab/market/market_store.dart';

/// A tunable setting declared in a script, e.g. `param threshold: 10 [0..100]`.
class ScriptParam {
  const ScriptParam(this.name, this.defaultValue, this.min, this.max);
  final String name;
  final double defaultValue, min, max;
}

final _paramPattern = RegExp(
  r'param\s+([A-Za-z_]\w*)\s*:\s*(-?\d+(?:\.\d+)?)\s*\[\s*(-?\d+(?:\.\d+)?)\s*\.\.\s*(-?\d+(?:\.\d+)?)\s*\]');

/// Finds every `param` declaration in [code]. Declarations with an empty range are ignored.
List<ScriptParam> parseParams(String code) {
  final params = <ScriptParam>[];
  for (final m in _paramPattern.allMatches(code)) {
    final p = ScriptParam(m.group(1)!, double.parse(m.group(2)!),
      double.parse(m.group(3)!), double.parse(m.group(4)!));
    if (p.max > p.min) params.add(p);
  }
  return params;
}

/// Deliberately constrained stub: no eval and no arbitrary code execution.
/// Recognises a `table` keyword, or a `label:` / `value:` stat spec where `value`
/// is a number or the name of a declared param.
Map<String, dynamic> runScript(String code, MarketStore market, Map<String, double> params) {
  if (code.trim().isEmpty) throw const FormatException('Script is empty');
  if (code.toLowerCase().contains('table')) {
    return {'type':'table','title':'Generated values','rows':[
      {'symbol':'AAA','value':market.latest('AAA').value},
      {'symbol':'BBB','value':market.latest('BBB').value},
      {'symbol':'CCC','value':market.latest('CCC').value},
    ]};
  }
  final labelMatch = RegExp(r'label\s*:\s*"([^"]+)"').firstMatch(code);
  final valueMatch = RegExp(r'\bvalue\s*:\s*(-?\d+(?:\.\d+)?|[A-Za-z_]\w*)').firstMatch(code);
  if (valueMatch == null) throw const FormatException('No value: field found');
  final token = valueMatch.group(1)!;
  final literal = num.tryParse(token);
  final double value;
  if (literal != null) {
    value = literal.toDouble();
  } else if (params.containsKey(token)) {
    value = params[token]!;
  } else {
    throw FormatException('Unknown name "$token" in value:');
  }
  return {'type':'stat','label':labelMatch?.group(1) ?? 'Value','value':value};
}
