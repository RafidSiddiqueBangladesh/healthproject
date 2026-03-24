import 'dart:math';

import 'package:flutter/material.dart';

class ThemePreset {
  const ThemePreset({
    required this.name,
    required this.primary,
    required this.accent,
    required this.orbColors,
    required this.isLight,
  });

  final String name;
  final Color primary;
  final Color accent;
  final List<Color> orbColors;
  final bool isLight;
}

class ThemeProvider extends ChangeNotifier {
  ThemeProvider();

  bool _isLight = false;
  Color _primary = const Color(0xFF7BA8FF);
  Color _accent = const Color(0xFFCE7BFF);
  List<Color> _orbColors = const [
    Color(0x596B0ACE),
    Color(0x593B35D4),
    Color(0x590874DE),
    Color(0x590AA67A),
    Color(0x59E05B00),
  ];

  bool get isLight => _isLight;
  Color get primary => _primary;
  Color get accent => _accent;
  List<Color> get orbColors => List<Color>.unmodifiable(_orbColors);

  static const presets = <ThemePreset>[
    ThemePreset(
      name: 'Aurora',
      primary: Color(0xFF7BA8FF),
      accent: Color(0xFFCE7BFF),
      isLight: false,
      orbColors: [
        Color(0x596B0ACE),
        Color(0x593B35D4),
        Color(0x590874DE),
        Color(0x590AA67A),
        Color(0x5913C238),
      ],
    ),
    ThemePreset(
      name: 'Sunset',
      primary: Color(0xFFFF8C42),
      accent: Color(0xFFFF4D8D),
      isLight: false,
      orbColors: [
        Color(0x59FF7A18),
        Color(0x59FF5E62),
        Color(0x59FF9966),
        Color(0x59E85D75),
        Color(0x59FFC371),
      ],
    ),
    ThemePreset(
      name: 'Ocean',
      primary: Color(0xFF3AA9FF),
      accent: Color(0xFF3ED3C5),
      isLight: false,
      orbColors: [
        Color(0x593B82F6),
        Color(0x590EA5E9),
        Color(0x5922D3EE),
        Color(0x592DD4BF),
        Color(0x5914B8A6),
      ],
    ),
    ThemePreset(
      name: 'Daylight',
      primary: Color(0xFF3D7DFF),
      accent: Color(0xFF9B5CFF),
      isLight: true,
      orbColors: [
        Color(0x4D93C5FD),
        Color(0x4DA78BFA),
        Color(0x4D60A5FA),
        Color(0x4D5EEAD4),
        Color(0x4DFDE68A),
      ],
    ),
  ];

  void applyPreset(ThemePreset preset) {
    _primary = preset.primary;
    _accent = preset.accent;
    _orbColors = List<Color>.from(preset.orbColors);
    _isLight = preset.isLight;
    notifyListeners();
  }

  void toggleMode() {
    _isLight = !_isLight;
    notifyListeners();
  }

  void updateOrbHue(int index, double hue) {
    if (index < 0 || index >= _orbColors.length) {
      return;
    }
    final hsl = HSLColor.fromColor(_orbColors[index]);
    _orbColors[index] = hsl.withHue(hue).toColor().withValues(alpha: _orbColors[index].a);
    notifyListeners();
  }

  void updatePrimaryHue(double hue) {
    final hsl = HSLColor.fromColor(_primary);
    _primary = hsl.withHue(hue).toColor();
    notifyListeners();
  }

  void updateAccentHue(double hue) {
    final hsl = HSLColor.fromColor(_accent);
    _accent = hsl.withHue(hue).toColor();
    notifyListeners();
  }

  void randomizeOrbs() {
    final random = Random();
    _orbColors = List<Color>.generate(_orbColors.length, (_) {
      final h = random.nextDouble() * 360;
      return HSLColor.fromAHSL(0.35, h, 0.88, _isLight ? 0.62 : 0.52).toColor();
    });
    notifyListeners();
  }

  ThemeData buildTheme() {
    final brightness = _isLight ? Brightness.light : Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      primary: _primary,
      secondary: _accent,
      brightness: brightness,
    );

    final textColor = _isLight ? const Color(0xFF1E293B) : const Color(0xFFF5F7FF);
    final subtleText = _isLight ? const Color(0xFF475569) : const Color(0xFFE8FCFF);

    return ThemeData(
      colorScheme: colorScheme,
      brightness: brightness,
      scaffoldBackgroundColor: _isLight ? const Color(0xFFF2F6FF) : const Color(0xFF0E1324),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _isLight ? Colors.white : const Color(0xFF0E1324),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _isLight ? const Color(0x66FFFFFF) : const Color(0x3DFFFFFF),
        labelStyle: TextStyle(color: subtleText),
        hintStyle: TextStyle(color: subtleText.withValues(alpha: 0.85)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: _isLight ? 0.3 : 0.45)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _primary.withValues(alpha: 0.85), width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: _isLight ? 0.35 : 0.12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
