import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VisitorModeProvider extends ChangeNotifier {
  static const String _prefsKey = 'is_visitor_mode';

  bool _loaded = false;
  bool _isVisitor = false;

  bool get loaded => _loaded;
  bool get isVisitor => _isVisitor;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isVisitor = prefs.getBool(_prefsKey) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setVisitor(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _isVisitor = value;
    await prefs.setBool(_prefsKey, value);
    notifyListeners();
  }
}
