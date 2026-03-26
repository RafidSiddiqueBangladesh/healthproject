import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../services/health_result_service.dart';
import '../services/mood_palette_service.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class HealthSuggestionsScreen extends StatefulWidget {
  const HealthSuggestionsScreen({super.key});

  @override
  State<HealthSuggestionsScreen> createState() => _HealthSuggestionsScreenState();
}

class _HealthSuggestionsScreenState extends State<HealthSuggestionsScreen> {
  bool _isLoading = true;
  String _selectedMood = 'Neutral';
  Map<String, Color> _moodPalette = MoodPaletteService.defaultPalette();
  String _aiSuggestion = '';
  List<Map<String, dynamic>> _videos = <Map<String, dynamic>>[];
  final Map<String, YoutubePlayerController> _videoControllers = <String, YoutubePlayerController>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final palette = await MoodPaletteService.loadPalette();
    final mood = await MoodPaletteService.loadSelectedMood();
    if (!mounted) return;

    setState(() {
      _moodPalette = palette;
      _selectedMood = mood;
      _isLoading = true;
    });

    try {
      final suggestion = await HealthResultService.fetchAiMoodSuggestion(_selectedMood);
      final videos = await HealthResultService.fetchMoodVideos(_selectedMood, maxResults: 6);
      final embeddableVideos = videos.where((video) => (_videoIdFromMap(video) ?? '').isNotEmpty).toList();
      if (!mounted) return;
      setState(() {
        _aiSuggestion = suggestion;
        _videos = embeddableVideos;
      });
      _syncEmbeddedVideo(embeddableVideos);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _aiSuggestion = '';
        _videos = <Map<String, dynamic>>[];
      });
      _disposeYoutubeControllers();
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  String? _videoIdFromMap(Map<String, dynamic> video) {
    final directId = (video['videoId'] ?? '').toString().trim();
    if (directId.isNotEmpty) return directId;

    final url = (video['url'] ?? '').toString().trim();
    if (url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final v = (uri.queryParameters['v'] ?? '').trim();
    if (v.isNotEmpty) return v;

    if (uri.host.contains('youtu.be')) {
      final path = uri.pathSegments.isNotEmpty ? uri.pathSegments.first.trim() : '';
      if (path.isNotEmpty) return path;
    }

    return null;
  }

  void _disposeYoutubeControllers() {
    for (final controller in _videoControllers.values) {
      controller.close();
    }
    _videoControllers.clear();
  }

  YoutubePlayerController _getOrCreateController(String videoId) {
    final existing = _videoControllers[videoId];
    if (existing != null) return existing;

    final controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
      ),
    );
    _videoControllers[videoId] = controller;
    return controller;
  }

  void _syncEmbeddedVideo(List<Map<String, dynamic>> videos) {
    final keepIds = <String>{};
    for (final video in videos) {
      final videoId = _videoIdFromMap(video);
      if (videoId == null || videoId.isEmpty) continue;
      keepIds.add(videoId);
      _getOrCreateController(videoId);
    }

    final staleIds = _videoControllers.keys.where((id) => !keepIds.contains(id)).toList();
    for (final id in staleIds) {
      _videoControllers[id]?.close();
      _videoControllers.remove(id);
    }
  }

  @override
  void dispose() {
    _disposeYoutubeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = _moodPalette[_selectedMood] ?? _moodPalette['Neutral']!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Mood Suggestions',
          icon: Icons.auto_awesome,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    children: [
                      LiquidGlassCard(
                        tint: moodColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mood: $_selectedMood',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Personalized AI support and YouTube therapy suggestions based on your latest mood and palette.',
                              style: TextStyle(color: Color(0xFFEAF3FF)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      LiquidGlassCard(
                        tint: moodColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AI Guidance',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _aiSuggestion.isEmpty ? 'No AI guidance available right now.' : _aiSuggestion,
                              style: const TextStyle(color: Color(0xFFEAF3FF)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      LiquidGlassCard(
                        tint: moodColor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'YouTube Therapy Videos',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_videos.isEmpty)
                              const Text(
                                'No videos found for this mood currently.',
                                style: TextStyle(color: Color(0xFFEAF3FF)),
                              )
                            else ...[
                              ..._videos.map((video) {
                                final title = (video['title'] ?? 'Video').toString();
                                final channel = (video['channelTitle'] ?? '').toString();
                                final videoId = _videoIdFromMap(video);
                                if (videoId == null || videoId.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                final controller = _getOrCreateController(videoId);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (channel.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2, bottom: 8),
                                          child: Text(
                                            channel,
                                            style: const TextStyle(color: Color(0xDDEAF3FF)),
                                          ),
                                        )
                                      else
                                        const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: AspectRatio(
                                          aspectRatio: 16 / 9,
                                          child: YoutubePlayerScaffold(
                                            controller: controller,
                                            builder: (context, player) => player,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
