import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/exercise_provider.dart';
import '../providers/user_provider.dart';

class ExerciseModule extends StatefulWidget {
  @override
  _ExerciseModuleState createState() => _ExerciseModuleState();
}

class _ExerciseModuleState extends State<ExerciseModule> {
  Map<int, Timer?> _timers = {};
  Map<int, int> _remainingTime = {};

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    for (int i = 0; i < provider.exercises.length; i++) {
      _remainingTime[i] = provider.exercises[i].duration * 60; // seconds
    }
  }

  void _startTimer(int index) {
    final provider = Provider.of<ExerciseProvider>(context, listen: false);
    if (_timers[index] != null) return;
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
  }

  String _formatTime(int seconds) {
    int min = seconds ~/ 60;
    int sec = seconds % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
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
      appBar: AppBar(
        title: Text('🏋️ Exercise Module'),
        backgroundColor: Colors.blue[700],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[100]!, Colors.purple[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ListView.builder(
            itemCount: provider.exercises.length,
            itemBuilder: (context, index) {
              final exercise = provider.exercises[index];
              bool isRunning = _timers[index] != null;
              return Card(
                margin: EdgeInsets.symmetric(vertical: 10),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.fitness_center, color: Colors.blue),
                        title: Text(exercise.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        subtitle: Text('${exercise.description}\nDuration: ${exercise.duration} min', style: TextStyle(color: Colors.grey[700])),
                      ),
                      if (isRunning)
                        Text(
                          'Time Left: ${_formatTime(_remainingTime[index]!)}',
                          style: TextStyle(fontSize: 20, color: Colors.red),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!isRunning)
                            ElevatedButton(
                              onPressed: () => _startTimer(index),
                              child: Text('Start'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            ),
                          SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: isRunning ? null : () => _completeExercise(index),
                            child: Text('Done'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}