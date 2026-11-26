import 'package:widget_lab/controller/layout_persistence.dart';
import 'package:widget_lab/domain/panel.dart';
import 'package:widget_lab/domain/script_runner.dart';
import 'package:widget_lab/store/workspace_store.dart';

/// Runs a panel's script and manages the values of its `param` settings.
class ScriptController {
  ScriptController(this.store, this.persistence);

  final WorkspaceStore store;
  final LayoutPersistence persistence;

  /// The settings declared in the panel's script.
  List<ScriptParam> declaredParams(Panel p) => parseParams(p.code);

  /// The current value of each declared setting: the user's value, or its default.
  Map<String, double> paramValues(Panel p) => {
    for (final d in declaredParams(p)) d.name: p.params[d.name] ?? d.defaultValue,
  };

  /// Runs the script. Throws a FormatException if the script is empty or can't be read.
  Map<String, dynamic> run(Panel p, double Function(String symbol) latest) =>
    runScript(p.code, latest, paramValues(p));

  /// Stores one setting's value and saves it with the layout.
  void setParam(Panel p, String name, double value) {
    p.params = {...p.params, name: value};
    store.notifyChanged();
    persistence.save(store);
  }
}
