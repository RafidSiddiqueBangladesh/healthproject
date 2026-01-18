import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/exercise.dart';
import 'user_provider.dart';

class ExerciseProvider with ChangeNotifier {
  List<Exercise> _exercises = [
    Exercise(name: 'Push-ups', description: 'Do 10 push-ups', duration: 5),
    Exercise(name: 'Squats', description: 'Do 15 squats', duration: 5),
    Exercise(name: 'Jumping Jacks', description: 'Do 20 jumping jacks', duration: 5),
  ];

  List<Exercise> get exercises => _exercises;

  void completeExercise(BuildContext context, int index) {
    // Add points for completing exercise
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.addPoints(10); // 10 points per exercise
    notifyListeners();
  }
}