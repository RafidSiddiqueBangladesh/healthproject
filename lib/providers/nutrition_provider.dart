import 'package:flutter/material.dart';
import '../models/food.dart';

class NutritionProvider with ChangeNotifier {
  List<Food> _foods = [];

  List<Food> get foods => _foods;

  double get totalCalories => _foods.fold(0.0, (sum, food) => sum + food.calories);

  void addFood(Food food) {
    _foods.add(food);
    notifyListeners();
  }

  void removeFood(int index) {
    _foods.removeAt(index);
    notifyListeners();
  }
}