import 'package:shared_preferences/shared_preferences.dart';

import '../models/overlay_theme.dart';

/// Menyimpan id tema overlay yang sedang dipilih user.
class ThemeRepository {
  static const _kSelectedThemeKey = 'pulse_selected_theme_id';

  Future<OverlayThemeData> getSelectedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kSelectedThemeKey);
    if (id == null) return kOverlayThemes.first;
    return themeById(id);
  }

  Future<void> setSelectedTheme(String themeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSelectedThemeKey, themeId);
  }
}
