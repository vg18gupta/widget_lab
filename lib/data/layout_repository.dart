import 'package:shared_preferences/shared_preferences.dart';

/// Where the layout is kept between visits. The workspace decides what the text contains;
/// this only stores and returns it.
abstract class LayoutRepository {
  /// The saved layout text, or null if nothing has been saved.
  Future<String?> read();
  Future<void> write(String text);
}

/// Stores the layout in the browser through shared_preferences.
class SharedPrefsLayoutRepository implements LayoutRepository {
  static const _key = 'widget_lab_layout_v1';

  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  @override
  Future<void> write(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, text);
  }
}
