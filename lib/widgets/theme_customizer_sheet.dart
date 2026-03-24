import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class ThemeCustomizerSheet extends StatelessWidget {
  const ThemeCustomizerSheet({super.key});

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
