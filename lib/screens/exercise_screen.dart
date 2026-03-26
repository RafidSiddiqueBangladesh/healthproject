import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/exercise_provider.dart';
import '../utils/web_iframe_registry.dart'
  if (dart.library.html) '../utils/web_iframe_registry_web.dart' as web_iframe;
import 'exercise_coach_screen.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class ExerciseModule extends StatefulWidget {
  @override
  _ExerciseModuleState createState() => _ExerciseModuleState();
}

class _ExerciseModuleState extends State<ExerciseModule> {
  Map<int, Timer?> _timers = {};
  Map<int, int> _remainingTime = {};
  final Set<String> _registeredWebViewTypes = <String>{};
  static const Map<String, String> _exerciseVideos = {
    'Push-ups': 'IODxDxX7oi4',
    'Squats': 'aclHkVaku9U',
    'Jumping Jacks': '2W4ZNSwoW_4',
  };

  ButtonStyle _actionButtonStyle({required bool isPrimary}) {
    return ElevatedButton.styleFrom(
      backgroundColor: isPrimary ? const Color(0xFF1E88E5) : const Color(0xFF00A86B),
      disabledBackgroundColor: const Color(0x665C6E82),
      foregroundColor: Colors.white,
      disabledForegroundColor: const Color(0xCCFFFFFF),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
    );
  }

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    for (int i = 0; i < provider.exercises.length; i++) {
      _remainingTime[i] = provider.exercises[i].duration * 60;
    }
  }

  Future<void> _startTimer(int index) async {
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    if (_timers[index] != null) return;
    final exercise = provider.exercises[index];
    final videoId = _exerciseVideos[exercise.name] ?? 'Fh7dMxZC4w4';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseCoachScreen(
          exerciseName: exercise.name,
          youtubeUrl: 'https://www.youtube.com/embed/$videoId',
        ),
      ),
    );

    if (!mounted || _timers[index] != null) return;

    _timers[index] = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime[index]! > 0) {
          _remainingTime[index] = _remainingTime[index]! - 1;
        } else {
          _completeExercise(index);
          timer.cancel();
          _timers[index] = null;
        }
      });
    });
  }

  void _completeExercise(int index) {
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    provider.completeExercise(context, index);
    setState(() {
      _remainingTime[index] = provider.exercises[index].duration * 60;
      _timers[index]?.cancel();
      _timers[index] = null;
    });
    _timers.values.forEach((timer) => timer?.cancel());
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildVideoWidget(String videoId) {
    if (kIsWeb) {
      return _buildWebVideoWidget(videoId);
    }

    if (!kIsWeb) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadRequest(
                Uri.parse('https://www.youtube.com/embed/$videoId?autoplay=0&modestbranding=1&rel=0'),
              ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildWebVideoWidget(String videoId) {
    final viewType = 'exercise-youtube-$videoId';
    final embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=0&modestbranding=1&rel=0';

    if (!_registeredWebViewTypes.contains(viewType)) {
      web_iframe.registerIFrame(viewType: viewType, src: embedUrl);
      _registeredWebViewTypes.add(viewType);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: HtmlElementView(viewType: viewType),
      ),
    );
  }

  @override
  void dispose() {
    _timers.values.forEach((timer) => timer?.cancel());
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExerciseProvider>(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Exercise Module',
          icon: Icons.fitness_center,
        ),
      ),
      body: LiquidGlassBackground(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 76, 12, 2),
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(provider.exercises.length, (index) {
              final exercise = provider.exercises[index];
              final isRunning = _timers[index] != null;
              final videoId = _exerciseVideos[exercise.name] ?? 'Fh7dMxZC4w4';

              return LiquidGlassCard(
                tint: const Color(0xFFCDE7FF),
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Column(
                    children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center, color: Color(0xFFE3EEFF), size: 16),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Duration: ${exercise.duration} min',
                                  style: const TextStyle(color: Color(0xDDECF1FF), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    _buildVideoWidget(videoId),
                    const SizedBox(height: 2),
                    if (isRunning)
                      Text(
                        'Time Left: ${_formatTime(_remainingTime[index]!)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFFD6D6)),
                      ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isRunning)
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              onPressed: () => _startTimer(index),
                              style: _actionButtonStyle(isPrimary: true),
                              child: const Text('Start Coach'),
                            ),
                          ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            onPressed: isRunning ? null : () => _completeExercise(index),
                            style: _actionButtonStyle(isPrimary: false),
                            child: const Text('Mark Done'),
                          ),
                        ),
                      ],
                    ),
                    ],
                  ),
                ),
              );
              }),
            ),
          ),
        ),
      ),
    );
  }
}