import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MoodPaletteService {
  static const String _paletteKey = 'mood_palette_v1';
  static const String _selectedMoodKey = 'selected_mood_v1';
  static const String _themePrefsKey = 'theme_prefs_v1';
  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
  static Timer? _selectedMoodSaveDebounce;
  static String _lastSyncedMood = 'Neutral';

  static const Map<String, int> _defaultHex = {
    'Happy': 0xFFFFD166,
    'Sad': 0xFF7EA8FF,
    'Neutral': 0xFF9BE7C4,
    'Astonished': 0xFFFF9E7A,
  };

  static const Map<String, dynamic> _defaultThemePrefs = {
    'isLight': false,
    'primaryHue': 220.0,
    'accentHue': 281.0,
    'orbHues': [263.0, 239.0, 276.0, 162.0, 24.0],
  };

  static const Map<String, Map<String, dynamic>> _defaultMoodThemes = {
    'Happy': {
      'isLight': false,
      'primaryHue': 44.0,
      'accentHue': 18.0,
      'orbHues': [44.0, 20.0, 355.0, 72.0, 108.0],
    },
    'Sad': {
      'isLight': false,
      'primaryHue': 220.0,
      'accentHue': 258.0,
      'orbHues': [220.0, 244.0, 266.0, 196.0, 176.0],
    },
    'Neutral': {
      'isLight': false,
      'primaryHue': 158.0,
      'accentHue': 205.0,
      'orbHues': [158.0, 184.0, 205.0, 228.0, 140.0],
    },
    'Astonished': {
      'isLight': false,
      'primaryHue': 16.0,
      'accentHue': 332.0,
      'orbHues': [16.0, 342.0, 294.0, 52.0, 24.0],
    },
  };

  static Map<String, Color> defaultPalette() {
    return _defaultHex.map((k, v) => MapEntry(k, Color(v)));
  }

  static Map<String, dynamic> defaultThemePreferences() {
    return {
      'isLight': _defaultThemePrefs['isLight'],
      'primaryHue': _defaultThemePrefs['primaryHue'],
      'accentHue': _defaultThemePrefs['accentHue'],
      'orbHues': List<double>.from(_defaultThemePrefs['orbHues'] as List<dynamic>),
    };
  }

  static Map<String, Map<String, dynamic>> defaultMoodThemes() {
    final result = <String, Map<String, dynamic>>{};
    for (final mood in _defaultHex.keys) {
      final source = _defaultMoodThemes[mood] ?? _defaultThemePrefs;
      result[mood] = {
        'isLight': source['isLight'] == true,
        'primaryHue': (source['primaryHue'] as num).toDouble(),
        'accentHue': (source['accentHue'] as num).toDouble(),
        'orbHues': List<double>.from((source['orbHues'] as List<dynamic>).map((v) => (v as num).toDouble())),
      };
    }
    return result;
  }

  static String _normalizeMoodName(String mood) {
    return _defaultHex.keys.contains(mood) ? mood : 'Neutral';
  }

  static Map<String, dynamic> _sanitizeThemeConfig(Map<String, dynamic> raw) {
    final defaults = defaultThemePreferences();
    return {
      'isLight': raw['isLight'] == true,
      'primaryHue': (raw['primaryHue'] as num?)?.toDouble() ?? (defaults['primaryHue'] as double),
      'accentHue': (raw['accentHue'] as num?)?.toDouble() ?? (defaults['accentHue'] as double),
      'orbHues': List<double>.from(
        (raw['orbHues'] as List<dynamic>? ?? (defaults['orbHues'] as List<double>)).map((v) => (v as num).toDouble()),
      ),
    };
  }

  static Map<String, Map<String, dynamic>> _sanitizeMoodThemes(Map<String, dynamic> raw) {
    final defaults = defaultMoodThemes();
    final result = <String, Map<String, dynamic>>{};
    for (final mood in _defaultHex.keys) {
      final moodRaw = Map<String, dynamic>.from(raw[mood] ?? defaults[mood] ?? const <String, dynamic>{});
      result[mood] = _sanitizeThemeConfig(moodRaw);
    }
    return result;
  }

  static Future<void> _saveLocalThemeBundle({
    required String selectedMood,
    required Map<String, Map<String, dynamic>> moodThemes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themePrefsKey,
      jsonEncode({
        'selectedMood': selectedMood,
        'moodThemes': moodThemes,
      }),
    );
  }

  static Future<Map<String, dynamic>> _loadLocalThemeBundle() async {
    final defaults = defaultMoodThemes();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themePrefsKey);

    if (raw == null || raw.isEmpty) {
      return {
        'selectedMood': 'Neutral',
        'moodThemes': defaults,
      };
    }

    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map<String, dynamic>);
      final selectedMood = _normalizeMoodName((decoded['selectedMood'] ?? 'Neutral').toString());

      // Backward compatibility: old storage had direct theme fields.
      final hasLegacyFlatTheme = decoded.containsKey('primaryHue') || decoded.containsKey('accentHue') || decoded.containsKey('orbHues');
      if (hasLegacyFlatTheme) {
        final legacy = _sanitizeThemeConfig(decoded);
        defaults[selectedMood] = legacy;
        return {
          'selectedMood': selectedMood,
          'moodThemes': defaults,
        };
      }

      final moodThemesRaw = Map<String, dynamic>.from(decoded['moodThemes'] ?? const <String, dynamic>{});
      final moodThemes = _sanitizeMoodThemes(moodThemesRaw);
      return {
        'selectedMood': selectedMood,
        'moodThemes': moodThemes,
      };
    } catch (_) {
      return {
        'selectedMood': 'Neutral',
        'moodThemes': defaults,
      };
    }
  }

  static Future<Map<String, dynamic>?> _fetchRemotePreferences() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/theme-preferences'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) return null;
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      if (payload['success'] != true) return null;
      return Map<String, dynamic>.from(payload['data'] ?? const <String, dynamic>{});
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveRemotePreferences(Map<String, dynamic> patch) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    try {
      await http.put(
        Uri.parse('$_apiBaseUrl/api/profile/theme-preferences'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(patch),
      );
    } catch (_) {}
  }

  static Future<Map<String, Color>> loadPalette() async {
    final remote = await _fetchRemotePreferences();
    if (remote != null) {
      final palette = defaultPalette();
      final remotePalette = Map<String, dynamic>.from(remote['moodPalette'] ?? const <String, dynamic>{});
      for (final mood in palette.keys) {
        final value = remotePalette[mood];
        if (value is num) {
          palette[mood] = Color(value.toInt());
        }
      }

      final prefs = await SharedPreferences.getInstance();
      final payload = palette.map((k, v) => MapEntry(k, v.toARGB32()));
      await prefs.setString(_paletteKey, jsonEncode(payload));
      return palette;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_paletteKey);
    final base = defaultPalette();

    if (raw == null || raw.isEmpty) {
      return base;
    }

    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      for (final mood in base.keys) {
        final value = decoded[mood];
        if (value is num) {
          base[mood] = Color(value.toInt());
        }
      }
      return base;
    } catch (_) {
      return base;
    }
  }

  static Future<void> savePalette(Map<String, Color> palette) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = palette.map((k, v) => MapEntry(k, v.toARGB32()));
    await prefs.setString(_paletteKey, jsonEncode(payload));
    await _saveRemotePreferences({'moodPalette': payload});
  }

  static Future<String> loadSelectedMood() async {
    final remote = await _fetchRemotePreferences();
    if (remote != null) {
      final remoteMood = (remote['selectedMood'] ?? 'Neutral').toString();
      final normalized = _defaultHex.keys.contains(remoteMood) ? remoteMood : 'Neutral';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_selectedMoodKey, normalized);
      return normalized;
    }

    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_selectedMoodKey);
    if (saved == null || saved.isEmpty || !_defaultHex.keys.contains(saved)) {
      return 'Neutral';
    }
    return saved;
  }

  static Future<void> saveSelectedMood(String mood) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = _defaultHex.keys.contains(mood) ? mood : 'Neutral';
    await prefs.setString(_selectedMoodKey, normalized);

    final bundle = await _loadLocalThemeBundle();
    await _saveLocalThemeBundle(
      selectedMood: normalized,
      moodThemes: Map<String, Map<String, dynamic>>.from(bundle['moodThemes'] as Map),
    );

    if (normalized == _lastSyncedMood) {
      return;
    }

    _selectedMoodSaveDebounce?.cancel();
    _selectedMoodSaveDebounce = Timer(const Duration(milliseconds: 1200), () async {
      await _saveRemotePreferences({'selectedMood': normalized});
      _lastSyncedMood = normalized;
    });
  }

  static Future<Map<String, dynamic>> loadThemePreferences() async {
    final defaults = defaultMoodThemes();
    final remote = await _fetchRemotePreferences();

    if (remote != null) {
      final selectedMood = _normalizeMoodName((remote['selectedMood'] ?? 'Neutral').toString());
      final remoteMoodThemesRaw = Map<String, dynamic>.from(remote['moodThemes'] ?? const <String, dynamic>{});
      final moodThemes = _sanitizeMoodThemes(remoteMoodThemesRaw);

      // Backward compatibility if backend returns only one global theme.
      final remoteTheme = Map<String, dynamic>.from(remote['theme'] ?? const <String, dynamic>{});
      if (remoteTheme.isNotEmpty && remoteMoodThemesRaw.isEmpty) {
        moodThemes[selectedMood] = _sanitizeThemeConfig(remoteTheme);
      }

      await _saveLocalThemeBundle(selectedMood: selectedMood, moodThemes: moodThemes);
      return Map<String, dynamic>.from(moodThemes[selectedMood] ?? defaults[selectedMood]!);
    }

    final localBundle = await _loadLocalThemeBundle();
    final selectedMood = _normalizeMoodName((localBundle['selectedMood'] ?? 'Neutral').toString());
    final moodThemes = Map<String, Map<String, dynamic>>.from(localBundle['moodThemes'] as Map);
    return Map<String, dynamic>.from(moodThemes[selectedMood] ?? defaults[selectedMood]!);
  }

  static Future<Map<String, Map<String, dynamic>>> loadMoodThemes() async {
    final remote = await _fetchRemotePreferences();
    if (remote != null) {
      final selectedMood = _normalizeMoodName((remote['selectedMood'] ?? 'Neutral').toString());
      final remoteMoodThemesRaw = Map<String, dynamic>.from(remote['moodThemes'] ?? const <String, dynamic>{});
      final moodThemes = _sanitizeMoodThemes(remoteMoodThemesRaw);

      final remoteTheme = Map<String, dynamic>.from(remote['theme'] ?? const <String, dynamic>{});
      if (remoteTheme.isNotEmpty && remoteMoodThemesRaw.isEmpty) {
        moodThemes[selectedMood] = _sanitizeThemeConfig(remoteTheme);
      }

      await _saveLocalThemeBundle(selectedMood: selectedMood, moodThemes: moodThemes);
      return moodThemes;
    }

    final local = await _loadLocalThemeBundle();
    return Map<String, Map<String, dynamic>>.from(local['moodThemes'] as Map);
  }

  static Future<void> saveThemePreferences(Map<String, dynamic> theme) async {
    final targetMoodRaw = (theme['mood'] ?? '').toString();
    final targetMood = targetMoodRaw.isEmpty ? await loadSelectedMood() : _normalizeMoodName(targetMoodRaw);
    final sanitized = _sanitizeThemeConfig(theme);

    final localBundle = await _loadLocalThemeBundle();
    final moodThemes = Map<String, Map<String, dynamic>>.from(localBundle['moodThemes'] as Map);
    moodThemes[targetMood] = sanitized;
    await _saveLocalThemeBundle(selectedMood: targetMood, moodThemes: moodThemes);

    await _saveRemotePreferences({
      'selectedMood': targetMood,
      'theme': sanitized,
    });
  }

  static String normalizeMood(String raw) {
    final value = raw.trim().toLowerCase();
    if (value.contains('happy')) return 'Happy';
    if (value.contains('sad')) return 'Sad';
    if (value.contains('astonished')) return 'Astonished';
    if (value.contains('neutral')) return 'Neutral';
    return 'Neutral';
  }
}
