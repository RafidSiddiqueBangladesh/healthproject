import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/health_result_service.dart';
import '../services/mood_palette_service.dart';
import '../providers/theme_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class HealthResultsScreen extends StatefulWidget {
  const HealthResultsScreen({super.key});

  @override
  State<HealthResultsScreen> createState() => _HealthResultsScreenState();
}

class _HealthResultsScreenState extends State<HealthResultsScreen> {
  static const List<Color> _presetColors = [
    Color(0xFFFFD166),
    Color(0xFFFF9E7A),
    Color(0xFFFF6B8A),
    Color(0xFF7EA8FF),
    Color(0xFF5FD2C8),
    Color(0xFF9BE7C4),
    Color(0xFFB59DFF),
    Color(0xFFFFC4E1),
  ];

  bool _isLoading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _tracking = <String, List<Map<String, dynamic>>>{};
  List<Map<String, dynamic>> _bmiLogs = <Map<String, dynamic>>[];
  Map<String, Color> _moodPalette = MoodPaletteService.defaultPalette();
  String _selectedMood = 'Neutral';

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final palette = await MoodPaletteService.loadPalette();
    final selected = await MoodPaletteService.loadSelectedMood();
    if (!mounted) return;
    setState(() {
      _moodPalette = palette;
      _selectedMood = selected;
    });
    _applyThemeForMood(_selectedMood);
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final data = await HealthResultService.fetchHealthSummary(limitPerType: 10);
      final trackingRaw = Map<String, dynamic>.from(data['tracking'] ?? <String, dynamic>{});
      final parsedTracking = <String, List<Map<String, dynamic>>>{};
      for (final entry in trackingRaw.entries) {
        final rows = List<Map<String, dynamic>>.from(entry.value ?? const <Map<String, dynamic>>[]);
        parsedTracking[entry.key] = rows;
      }

      setState(() {
        _tracking = parsedTracking;
        _bmiLogs = List<Map<String, dynamic>>.from(data['bmi'] ?? const <Map<String, dynamic>>[]);
        _isLoading = false;
      });

      final moodFromResult = _detectMoodFromResults(parsedTracking);
      if (moodFromResult != null && moodFromResult != _selectedMood) {
        setState(() {
          _selectedMood = moodFromResult;
        });
        await MoodPaletteService.saveSelectedMood(moodFromResult);
        _applyThemeForMood(moodFromResult);
      }
    } catch (e) {
      setState(() {
        _error = 'Could not load results: $e';
        _isLoading = false;
      });
    }
  }

  String _niceType(String raw) {
    switch (raw) {
      case 'face_detection':
        return 'Face Detection';
      case 'shoulder_detection':
        return 'Shoulder Detection';
      case 'hand_detection':
        return 'Hand Detection';
      case 'live_monitor':
        return 'Live Monitor';
      default:
        return raw.replaceAll('_', ' ');
    }
  }

  String? _detectMoodFromResults(Map<String, List<Map<String, dynamic>>> tracking) {
    final faceRows = tracking['face_detection'];
    if (faceRows == null || faceRows.isEmpty) return null;
    final latest = (faceRows.first['label'] ?? '').toString();
    if (latest.isEmpty) return null;
    return MoodPaletteService.normalizeMood(latest);
  }

  void _applyThemeForMood(String mood) {
    final color = _moodPalette[mood] ?? _moodPalette['Neutral']!;
    final hsl = HSLColor.fromColor(color);
    final accentHue = (hsl.hue + 38.0) % 360.0;
    final theme = context.read<ThemeProvider>();
    theme.updatePrimaryHue(hsl.hue);
    theme.updateAccentHue(accentHue);
  }

  Color _colorForMood(String mood) {
    return _moodPalette[mood] ?? _moodPalette['Neutral'] ?? const Color(0xFF7EA8FF);
  }

  Color _tintForType(String rawType) {
    final base = _colorForMood(_selectedMood);
    final hsl = HSLColor.fromColor(base);

    HSLColor shifted;
    switch (rawType) {
      case 'face_detection':
        shifted = hsl.withHue((hsl.hue + 18) % 360).withLightness((hsl.lightness + 0.10).clamp(0.0, 1.0));
        break;
      case 'shoulder_detection':
        shifted = hsl.withHue((hsl.hue + 78) % 360).withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0));
        break;
      case 'hand_detection':
        shifted = hsl.withHue((hsl.hue + 132) % 360).withLightness((hsl.lightness + 0.07).clamp(0.0, 1.0));
        break;
      case 'live_monitor':
        shifted = hsl.withHue((hsl.hue + 210) % 360).withLightness((hsl.lightness + 0.05).clamp(0.0, 1.0));
        break;
      default:
        shifted = hsl.withLightness((hsl.lightness + 0.08).clamp(0.0, 1.0));
    }

    return shifted.toColor();
  }

  Color _surfaceFor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 1.0)).toColor().withValues(alpha: 0.38);
  }

  Color _toneFrom(Color base, {double hueShift = 0, double lightnessShift = 0, double alpha = 0.45}) {
    final hsl = HSLColor.fromColor(base);
    final shifted = hsl
        .withHue((hsl.hue + hueShift) % 360)
        .withLightness((hsl.lightness + lightnessShift).clamp(0.0, 1.0))
        .toColor();
    return shifted.withValues(alpha: alpha);
  }

  Color _scoreBadgeColor(dynamic score) {
    final value = double.tryParse(score?.toString() ?? '0') ?? 0;
    if (value >= 85) return const Color(0xFF22C55E);
    if (value >= 65) return const Color(0xFF3B82F6);
    if (value >= 45) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _formatSavedDate(String raw) {
    if (raw.trim().isEmpty) return 'N/A';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final local = parsed.toLocal();
    final mm = local.month.toString().padLeft(2, '0');
    final dd = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '${local.year}-$mm-$dd $hh:$min';
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0x3AFFFFFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFF2FAFF), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              if (subtitle != null && subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Color(0xD9ECF7FF)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricChip({required String label, required String value, Color? chipColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: chipColor ?? const Color(0x2AFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x45FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xD3E9F6FF), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildKeyValueRow({required String keyLabel, required String value}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$keyLabel: ',
              style: const TextStyle(color: Color(0xFFE9F7FF), fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xDFF2FAFF)),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _detailsOf(Map<String, dynamic> row) {
    return Map<String, dynamic>.from(row['details'] ?? const <String, dynamic>{});
  }

  int _extractRepCount(Map<String, dynamic> row) {
    final details = _detailsOf(row);
    final rep = details['repCount'];
    if (rep is int) return rep;
    if (rep is num) return rep.toInt();
    return int.tryParse(rep?.toString() ?? '') ?? 0;
  }

  String _extractExerciseName(Map<String, dynamic> row) {
    final details = _detailsOf(row);
    final fromDetails = (details['exerciseName'] ?? '').toString().trim();
    if (fromDetails.isNotEmpty) return fromDetails;
    final label = (row['label'] ?? '').toString();
    final dash = label.indexOf(' - ');
    if (dash > 0) return label.substring(0, dash).trim();
    return 'Exercise';
  }

  Widget _buildInfoPill({required IconData icon, required String text, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? const Color(0x2FFFFFFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFEAF6FF)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(color: Color(0xFFF2F9FF), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveHighlightsCard(List<Map<String, dynamic>> rows) {
    final sorted = [...rows]
      ..sort((a, b) => (b['createdAt'] ?? '').toString().compareTo((a['createdAt'] ?? '').toString()));
    final latest = sorted.first;
    final bestReps = rows.fold<int>(0, (best, row) {
      final rep = _extractRepCount(row);
      return rep > best ? rep : best;
    });
    final latestExercise = _extractExerciseName(latest);
    final latestReps = _extractRepCount(latest);
    final latestDate = _formatSavedDate((latest['createdAt'] ?? '').toString());

    return LiquidGlassCard(
      tint: const Color(0xFFD7DBFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.sports_gymnastics,
            title: 'Live Workout Insights',
            subtitle: 'Dynamic rep and exercise overview from saved sessions',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMetricChip(
                label: 'Sessions',
                value: '${rows.length}',
                chipColor: _toneFrom(_tintForType('live_monitor'), hueShift: 210),
              ),
              _buildMetricChip(
                label: 'Best Reps',
                value: '$bestReps',
                chipColor: _toneFrom(_tintForType('live_monitor'), hueShift: 120),
              ),
              _buildMetricChip(
                label: 'Latest',
                value: '$latestExercise • $latestReps',
                chipColor: _toneFrom(_tintForType('live_monitor'), hueShift: 30),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildKeyValueRow(keyLabel: 'Latest Saved', value: latestDate),
        ],
      ),
    );
  }

  Future<void> _openPaletteEditor() async {
    final localPalette = Map<String, Color>.from(_moodPalette);
    var localMood = _selectedMood;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: LiquidGlassCard(
                tint: const Color(0xFFE1EEFF),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mood Color Palette',
                      style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ['Happy', 'Sad', 'Neutral', 'Astonished'].map((mood) {
                        final selected = localMood == mood;
                        final moodColor = localPalette[mood] ?? _colorForMood(mood);
                        return ChoiceChip(
                          label: Text(mood),
                          selected: selected,
                          selectedColor: moodColor.withValues(alpha: 0.55),
                          backgroundColor: const Color(0x28FFFFFF),
                          side: BorderSide(color: selected ? Colors.white : const Color(0x66FFFFFF)),
                          labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          onSelected: (_) {
                            setModalState(() {
                              localMood = mood;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    const Text('Pick a color', style: TextStyle(color: Color(0xFFEAF6FF))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _presetColors.map((color) {
                        final selected = localPalette[localMood]?.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setModalState(() {
                              localPalette[localMood] = color;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            width: selected ? 40 : 34,
                            height: selected ? 40 : 34,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selected ? Colors.white : Colors.white.withValues(alpha: 0.4),
                                width: selected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: BorderSide(
                                color: (_moodPalette[_selectedMood] ?? const Color(0xFF7EA8FF)).withValues(alpha: 0.85),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: localPalette[localMood] ?? _colorForMood(localMood),
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              await MoodPaletteService.savePalette(localPalette);
                              await MoodPaletteService.saveSelectedMood(localMood);
                              if (!mounted) return;
                              setState(() {
                                _moodPalette = localPalette;
                                _selectedMood = localMood;
                              });
                              _applyThemeForMood(localMood);
                              if (!context.mounted) return;
                              Navigator.of(context).pop();
                            },
                            child: const Text('Save Palette'),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = _colorForMood(_selectedMood);
    final totalTracking = _tracking.values.fold<int>(0, (sum, rows) => sum + rows.length);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Health Results',
          icon: Icons.history,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPaletteEditor,
        icon: const Icon(Icons.palette),
        label: const Text('Mood Palette'),
        backgroundColor: moodColor,
        foregroundColor: Colors.white,
      ),
      body: LiquidGlassBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        moodColor.withValues(alpha: 0.26),
                        Colors.transparent,
                        moodColor.withValues(alpha: 0.16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        children: [
                          if (_error != null) ...[
                            LiquidGlassCard(
                              tint: const Color(0xFFFFDDE2),
                              child: Text(_error!, style: const TextStyle(color: Colors.white)),
                            ),
                            const SizedBox(height: 12),
                          ],
                          LiquidGlassCard(
                            tint: moodColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionHeader(
                                  icon: Icons.mood,
                                  title: 'Current Mood: $_selectedMood',
                                  subtitle: 'Adaptive color theme based on your latest face result',
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildMetricChip(label: 'Tracking Logs', value: '$totalTracking'),
                                    _buildMetricChip(label: 'BMI Logs', value: '${_bmiLogs.length}'),
                                    _buildMetricChip(label: 'Mood Presets', value: '${_moodPalette.length}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          if ((_tracking['live_monitor'] ?? const <Map<String, dynamic>>[]).isNotEmpty) ...[
                            _buildLiveHighlightsCard(_tracking['live_monitor']!),
                            const SizedBox(height: 14),
                          ],
                          _buildBmiSection(),
                          const SizedBox(height: 14),
                          ..._tracking.entries.map((e) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTrackingSection(_niceType(e.key), e.value.take(3).toList()),
                              )),
                          if (_tracking.isEmpty && _bmiLogs.isEmpty)
                            const LiquidGlassCard(
                              tint: Color(0xFFE8F1FF),
                              child: Text('No saved health data yet.', style: TextStyle(color: Colors.white)),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBmiSection() {
    final bmiTint = _tintForType('bmi');
    return LiquidGlassCard(
      tint: bmiTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.monitor_weight,
            title: 'BMI History (Last 3)',
            subtitle: 'Your latest body-mass trend snapshots',
          ),
          const SizedBox(height: 8),
          if (_bmiLogs.isEmpty)
            const Text('No BMI records found.', style: TextStyle(color: Color(0xFFEFF8FF)))
          else
            ..._bmiLogs.take(3).map((row) {
              final date = (row['createdAt'] ?? '').toString();
              final category = (row['category'] ?? 'N/A').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceFor(bmiTint),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('BMI: ${row['bmi']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x36FFFFFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(category, style: const TextStyle(color: Color(0xFFF3FCFF), fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildKeyValueRow(
                        keyLabel: 'Body Data',
                        value: 'Height ${row['heightCm']} cm, Weight ${row['weightKg']} kg',
                      ),
                      _buildKeyValueRow(
                        keyLabel: 'Saved',
                        value: _formatSavedDate(date),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTrackingSection(String title, List<Map<String, dynamic>> rows) {
    final trackingTint = _tintForType(title.toLowerCase().replaceAll(' ', '_'));
    return LiquidGlassCard(
      tint: trackingTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            icon: Icons.insights,
            title: '$title (Last 3)',
            subtitle: 'Latest saved predictions and signals',
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Text('No records found.', style: TextStyle(color: Color(0xFFEFF8FF)))
          else
            ...rows.map((row) {
              final details = _detailsOf(row);
              final date = (row['createdAt'] ?? '').toString();
              final label = (row['label'] ?? 'N/A').toString();
              final exerciseName = (details['exerciseName'] ?? '').toString();
              final repCount = details['repCount'];
              final formScore = details['formScore'];
              final faceDetected = details['faceDetected'];
              final shoulderActive = details['shoulderActive'];
              final handActive = details['handActive'];
              final feedback = (details['exerciseFeedback'] ?? '').toString();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _surfaceFor(trackingTint),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Result: $label',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (row['score'] != null)
                            Builder(
                              builder: (_) {
                                final badge = _scoreBadgeColor(row['score']);
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: badge.withValues(alpha: 0.38),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'Score ${row['score']}',
                                    style: const TextStyle(color: Color(0xFFEFF8FF), fontSize: 11),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (exerciseName.isNotEmpty || repCount != null || formScore != null)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (exerciseName.isNotEmpty)
                              _buildInfoPill(
                                icon: Icons.fitness_center,
                                text: exerciseName,
                                color: _toneFrom(trackingTint, hueShift: 0),
                              ),
                            if (repCount != null)
                              _buildInfoPill(
                                icon: Icons.repeat,
                                text: '$repCount reps',
                                color: _toneFrom(trackingTint, hueShift: 50),
                              ),
                            if (formScore != null)
                              _buildInfoPill(
                                icon: Icons.stars,
                                text: 'Form $formScore',
                                color: _toneFrom(trackingTint, hueShift: 100),
                              ),
                          ],
                        ),
                      if (faceDetected != null || shoulderActive != null || handActive != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (faceDetected != null)
                              _buildInfoPill(
                                icon: Icons.face,
                                text: 'Face ${faceDetected == true ? 'On' : 'Off'}',
                                color: _toneFrom(trackingTint, hueShift: 10),
                              ),
                            if (shoulderActive != null)
                              _buildInfoPill(
                                icon: Icons.accessibility_new,
                                text: 'Shoulder ${shoulderActive == true ? 'Active' : 'Idle'}',
                                color: _toneFrom(trackingTint, hueShift: 70),
                              ),
                            if (handActive != null)
                              _buildInfoPill(
                                icon: Icons.pan_tool_alt,
                                text: 'Hand ${handActive == true ? 'Active' : 'Idle'}',
                                color: _toneFrom(trackingTint, hueShift: 140),
                              ),
                          ],
                        ),
                      ],
                      if (feedback.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _buildKeyValueRow(keyLabel: 'Coach', value: feedback),
                      ],
                      if (details.isNotEmpty)
                        _buildKeyValueRow(
                          keyLabel: 'Details',
                          value: details.entries.map((d) => '${d.key}: ${d.value}').join(', '),
                        ),
                      _buildKeyValueRow(
                        keyLabel: 'Saved',
                        value: _formatSavedDate(date),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
