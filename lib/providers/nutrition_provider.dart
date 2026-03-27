import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food.dart';

class NutritionProvider with ChangeNotifier {
  final List<Food> _foods = [];
  bool _isLoading = false;

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://healthproject-ermg.onrender.com',
  );

  List<Food> get foods => List<Food>.unmodifiable(_foods);
  bool get isLoading => _isLoading;

  double get totalCalories => _foods.fold(0.0, (sum, food) => sum + food.calories);

  Future<void> loadFoods() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/nutrition-logs'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload['success'] == true) {
          final rows = List<Map<String, dynamic>>.from(payload['data'] ?? []);
          _foods
            ..clear()
            ..addAll(rows.map((row) => Food(
                  id: (row['id'] ?? row['_id'])?.toString(),
                  name: (row['name'] ?? '').toString(),
                  calories: ((row['calories'] ?? 0) as num).toDouble(),
                  amountLabel: (row['amountLabel'] ?? 'Default').toString(),
                  grams: ((row['grams'] ?? 0) as num).toDouble(),
                  matchedReference: row['matchedReference']?.toString(),
                  createdAt: row['createdAt'] != null ? DateTime.tryParse(row['createdAt'].toString()) : null,
                  price: ((row['price'] ?? 0) as num).toDouble(),
                )));
        }
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addFood(Food food) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/nutrition-logs'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': food.name,
        'calories': food.calories,
        'amountLabel': food.amountLabel,
        'grams': food.grams,
        'matchedReference': food.matchedReference,
        'price': food.price,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      final row = Map<String, dynamic>.from(payload['data'] ?? {});
      _foods.insert(
        0,
        Food(
          id: (row['id'] ?? row['_id'])?.toString(),
          name: (row['name'] ?? food.name).toString(),
          calories: ((row['calories'] ?? food.calories) as num).toDouble(),
          amountLabel: (row['amountLabel'] ?? food.amountLabel).toString(),
          grams: ((row['grams'] ?? food.grams) as num).toDouble(),
          matchedReference: row['matchedReference']?.toString() ?? food.matchedReference,
          createdAt: row['createdAt'] != null ? DateTime.tryParse(row['createdAt'].toString()) : DateTime.now(),
          price: ((row['price'] ?? food.price) as num).toDouble(),
        ),
      );
      notifyListeners();
      return;
    }

    throw Exception('Failed to save nutrition entry');
  }

  Future<void> removeFood(int index) async {
    if (index < 0 || index >= _foods.length) return;
    final id = _foods[index].id;

    if (id == null || id.isEmpty) {
      _foods.removeAt(index);
      notifyListeners();
      return;
    }

    await removeFoodById(id);
  }

  Future<void> removeFoodById(String id) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/api/profile/nutrition-logs/$id'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      _foods.removeWhere((food) => food.id == id);
      notifyListeners();
      return;
    }

    throw Exception('Failed to remove nutrition entry');
  }
}