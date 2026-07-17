import 'package:flutter/material.dart';

/// Definisi satu tema tampilan overlay: warna kartu swatch di layar
/// kustomisasi, warna latar widget overlay itu sendiri, warna teks,
/// dan warna aksen untuk angka FPS/mini-bars.
class OverlayThemeData {
  final String id;
  final String name;
  final List<Color> swatchGradient;
  final Color widgetBackground;
  final Color textColor;
  final Color accentColor;

  const OverlayThemeData({
    required this.id,
    required this.name,
    required this.swatchGradient,
    required this.widgetBackground,
    required this.textColor,
    required this.accentColor,
  });
}

/// 6 preset tema, warnanya senada dengan mockup HTML yang sudah disetujui.
const List<OverlayThemeData> kOverlayThemes = [
  OverlayThemeData(
    id: 'ios',
    name: 'iOS Bright',
    swatchGradient: [Color(0xFFFFFFFF), Color(0xFFCFE8FF)],
    widgetBackground: Color(0xD9FFFFFF),
    textColor: Color(0xFF1C1C1E),
    accentColor: Color(0xFF0A84FF),
  ),
  OverlayThemeData(
    id: 'midnight',
    name: 'Midnight Cyan',
    swatchGradient: [Color(0xFF1B2735), Color(0xFF5FD4D6)],
    widgetBackground: Color(0xBF141920),
    textColor: Colors.white,
    accentColor: Color(0xFF5FD4D6),
  ),
  OverlayThemeData(
    id: 'amber',
    name: 'Amber HUD',
    swatchGradient: [Color(0xFF1A1A1A), Color(0xFFFFB020)],
    widgetBackground: Color(0xD10F1113),
    textColor: Colors.white,
    accentColor: Color(0xFFFFB020),
  ),
  OverlayThemeData(
    id: 'sunset',
    name: 'Sunset Glow',
    swatchGradient: [Color(0xFF3A1C40), Color(0xFFFF7A59)],
    widgetBackground: Color(0xBF281423),
    textColor: Colors.white,
    accentColor: Color(0xFFFF7A59),
  ),
  OverlayThemeData(
    id: 'forest',
    name: 'Forest Glass',
    swatchGradient: [Color(0xFF0F2A1C), Color(0xFF30D158)],
    widgetBackground: Color(0xBF0F1E14),
    textColor: Colors.white,
    accentColor: Color(0xFF30D158),
  ),
  OverlayThemeData(
    id: 'mono',
    name: 'Mono Grayscale',
    swatchGradient: [Color(0xFF000000), Color(0xFFFFFFFF)],
    widgetBackground: Color(0xCC000000),
    textColor: Colors.white,
    accentColor: Color(0xFFE5E5EA),
  ),
];

OverlayThemeData themeById(String id) =>
    kOverlayThemes.firstWhere((t) => t.id == id, orElse: () => kOverlayThemes.first);
