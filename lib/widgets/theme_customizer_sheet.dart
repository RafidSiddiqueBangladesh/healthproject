import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/mood_palette_service.dart';

class ThemeCustomizerSheet extends StatefulWidget {
  const ThemeCustomizerSheet({super.key});

  @override
  State<ThemeCustomizerSheet> createState() => _ThemeCustomizerSheetState();
}

class _ThemeCustomizerSheetState extends State<ThemeCustomizerSheet> {
  static const List<String> _moods = ['Happy', 'Sad', 'Neutral', 'Astonished'];
  String _editingMood = 'Neutral';
  bool _isSwitchingMood = false;

  @override
  void initState() {
    super.initState();
    _loadInitialMood();
  }

  Future<void> _loadInitialMood() async {
    final mood = await MoodPaletteService.loadSelectedMood();
    if (!mounted) return;
    setState(() {
      _editingMood = mood;
    });
  }

  Future<void> _switchEditingMood(String mood, ThemeProvider theme) async {
    if (_isSwitchingMood || mood == _editingMood) return;
    setState(() {
      _isSwitchingMood = true;
      _editingMood = mood;
    });

    await MoodPaletteService.saveSelectedMood(mood);
    final all = await MoodPaletteService.loadMoodThemes();
    final selected = all[mood] ?? MoodPaletteService.defaultThemePreferences();

    theme.applyThemeSnapshot(
      isLight: selected['isLight'] == true,
      primaryHue: (selected['primaryHue'] as num?)?.toDouble() ?? 220,
      accentHue: (selected['accentHue'] as num?)?.toDouble() ?? 281,
      orbHues: List<double>.from((selected['orbHues'] as List<dynamic>? ?? const <double>[263, 239, 276, 162, 24]).map((v) => (v as num).toDouble())),
      persist: false,
    );

    if (!mounted) return;
    setState(() {
      _isSwitchingMood = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Theme & Background',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment<bool>(value: false, label: Text('Dark')),
                          ButtonSegment<bool>(value: true, label: Text('Light')),
                        ],
                        selected: {theme.isLight},
                        onSelectionChanged: (value) {
                          final target = value.first;
                          if (target != theme.isLight) {
                            theme.toggleMode();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Mood Theme Editor', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _moods
                        .map(
                          (mood) => ChoiceChip(
                            label: Text(mood),
                            selected: _editingMood == mood,
                            onSelected: (_) => _switchEditingMood(mood, theme),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isSwitchingMood
                        ? 'Loading $_editingMood theme...'
                        : 'Editing: $_editingMood (all changes save for this mood)',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  const Text('Presets', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ThemeProvider.presets
                        .map(
                          (preset) => ActionChip(
                            label: Text(preset.name),
                            onPressed: () => theme.applyPreset(preset),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _HueSlider(
                    label: 'Primary Hue',
                    color: theme.primary,
                    onChanged: theme.updatePrimaryHue,
                  ),
                  const SizedBox(height: 12),
                  _HueSlider(
                    label: 'Accent Hue',
                    color: theme.accent,
                    onChanged: theme.updateAccentHue,
                  ),
                  const SizedBox(height: 16),
                  const Text('Background Orb Hues', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  for (int i = 0; i < theme.orbColors.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _HueSlider(
                        label: 'Orb ${i + 1}',
                        color: theme.orbColors[i],
                        onChanged: (hue) => theme.updateOrbHue(i, hue),
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: theme.randomizeOrbs,
                      icon: const Icon(Icons.shuffle_rounded),
                      label: const Text('Randomize Background'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HueSlider extends StatelessWidget {
  const _HueSlider({
    required this.label,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final hue = HSLColor.fromColor(color).hue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              ),
            ),
          ],
        ),
        Slider(
          min: 0,
          max: 360,
          value: hue,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
