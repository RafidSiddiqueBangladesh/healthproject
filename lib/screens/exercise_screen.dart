import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
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
  static const Map<String, String> _exerciseVideos = {
    'Push-ups': 'https://www.youtube.com/embed/IODxDxX7oi4',
    'Squats': 'https://www.youtube.com/embed/aclHkVaku9U',
    'Jumping Jacks': 'https://www.youtube.com/embed/c4DAnQ6DtF8',
  };

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
    final url = _exerciseVideos[exercise.name] ?? 'https://www.youtube.com/embed/Fh7dMxZC4w4';

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseCoachScreen(
          exerciseName: exercise.name,
          youtubeUrl: url,
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
          padding: const EdgeInsets.fromLTRB(16, 104, 16, 24),
          child: ListView.builder(
            itemCount: provider.exercises.length,
            itemBuilder: (context, index) {
              final exercise = provider.exercises[index];
              final isRunning = _timers[index] != null;
              return LiquidGlassCard(
                tint: const Color(0xFFCDE7FF),
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.fitness_center, color: Color(0xFFE3EEFF)),
                      title: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        '${exercise.description}\nDuration: ${exercise.duration} min',
                        style: const TextStyle(color: Color(0xDDECF1FF)),
                      ),
                    ),
                    if (isRunning)
                      Text(
                        'Time Left: ${_formatTime(_remainingTime[index]!)}',
                        style: const TextStyle(fontSize: 20, color: Color(0xFFFFD6D6)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isRunning)
                          ElevatedButton(
                            onPressed: () => _startTimer(index),
                            child: const Text('Start'),
                          ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isRunning ? null : () => _completeExercise(index),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}