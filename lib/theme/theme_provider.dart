import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  static const String _themeKey = 'theme_mode';

  bool get isDarkMode => _isDarkMode;

  ThemeProvider() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    notifyListeners();
  }

  // Brand accents
  static const Color navyBlue = Color(0xFF123CBE);
  static const Color gold = Color(0xFFFFB206);

  ThemeData get lightTheme {
    final cs = ColorScheme.fromSeed(
      seedColor: navyBlue,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyBlue,
          foregroundColor: gold,
        ),
      ),
    );
  }

  ThemeData get darkTheme {
    final base = ColorScheme.fromSeed(
      seedColor: navyBlue,
      brightness: Brightness.dark,
    );
    // Base dark background with white overlay derived surfaces
    const bg = Color(0xFF121212); // requested background
    final surface = _whiteOverlay(bg, 0.08);        // 8% white overlay
    final surfaceVariant = _whiteOverlay(bg, 0.12); // 12% white overlay
    final cs = base.copyWith(
      background: bg,
      surface: surface,
      surfaceVariant: surfaceVariant,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      scaffoldBackgroundColor: cs.background,
      cardColor: cs.surface,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyBlue,
          foregroundColor: gold,
        ),
      ),
    );
  }

  // Compose a white overlay with given opacity over a base color
  static Color _whiteOverlay(Color base, double opacity) {
    assert(opacity >= 0 && opacity <= 1);
    final r = (255 * opacity + base.red * (1 - opacity)).round().clamp(0, 255);
    final g = (255 * opacity + base.green * (1 - opacity)).round().clamp(0, 255);
    final b = (255 * opacity + base.blue * (1 - opacity)).round().clamp(0, 255);
    return Color.fromARGB(255, r, g, b);
  }

  // Helper methods for dynamic colors that adapt automatically
  Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).colorScheme.background;
  }

  Color getCardColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  Color getTextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color getSubtextColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
  }

  Color getBorderColor(BuildContext context) {
    return Theme.of(context).colorScheme.outlineVariant;
  }
}
