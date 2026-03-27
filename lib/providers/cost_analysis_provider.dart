import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';

class CookingCostItem {
  const CookingCostItem({
    required this.id,
    required this.name,
    required this.amountLabel,
    required this.price,
    required this.entryDate,
    required this.expiryDate,
    required this.usedDefaultExpiry,
  });

  final String id;
  final String name;
  final String amountLabel;
  final double price;
  final DateTime entryDate;
  final DateTime expiryDate;
  final bool usedDefaultExpiry;
}

class ManualCostEntry {
  const ManualCostEntry({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });

  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
}

class CostAnalysisProvider with ChangeNotifier {
  final List<CookingCostItem> _cookingItems = [];
  final List<ManualCostEntry> _manualEntries = [];
  bool _isLoadingCookingItems = false;
  bool _isLoadingManualItems = false;

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://healthproject-ermg.onrender.com',
  );

  List<CookingCostItem> get cookingItems => List.unmodifiable(_cookingItems);
  List<ManualCostEntry> get manualEntries => List.unmodifiable(_manualEntries);
  bool get isLoadingCookingItems => _isLoadingCookingItems;
  bool get isLoadingManualItems => _isLoadingManualItems;

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> loadCookingItems() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    _isLoadingCookingItems = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/cooking-items'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload['success'] == true) {
          final rows = List<Map<String, dynamic>>.from(payload['data'] ?? []);
          _cookingItems
            ..clear()
            ..addAll(rows.map((row) => CookingCostItem(
                  id: (row['id'] ?? row['_id']).toString(),
                  name: (row['name'] ?? '').toString(),
                  amountLabel: (row['amountLabel'] ?? 'Default').toString(),
                  price: ((row['price'] ?? 0) as num).toDouble(),
                  entryDate: DateTime.tryParse((row['entryDate'] ?? '').toString()) ?? DateTime.now(),
                  expiryDate: DateTime.tryParse((row['expiryDate'] ?? '').toString()) ?? DateTime.now(),
                  usedDefaultExpiry: row['usedDefaultExpiry'] == true,
                )));
        }
      }
    } finally {
      _isLoadingCookingItems = false;
      notifyListeners();
    }
  }

  Future<void> loadManualCosts() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    _isLoadingManualItems = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile/manual-costs'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body);
        if (payload['success'] == true) {
          final rows = List<Map<String, dynamic>>.from(payload['data'] ?? []);
          _manualEntries
            ..clear()
            ..addAll(rows.map((row) => ManualCostEntry(
                  id: (row['id'] ?? row['_id']).toString(),
                  title: (row['title'] ?? '').toString(),
                  category: (row['category'] ?? 'Food').toString(),
                  amount: ((row['amount'] ?? 0) as num).toDouble(),
                  date: DateTime.tryParse((row['date'] ?? '').toString()) ?? DateTime.now(),
                )));
        }
      }
    } finally {
      _isLoadingManualItems = false;
      notifyListeners();
    }
  }

  Future<void> addCookingItem({
    required String name,
    required String amountLabel,
    required double price,
    required DateTime entryDate,
    required DateTime expiryDate,
    required bool usedDefaultExpiry,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/cooking-items'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': name,
        'amountLabel': amountLabel,
        'price': price,
        'entryDate': entryDate.toIso8601String(),
        'expiryDate': expiryDate.toIso8601String(),
        'usedDefaultExpiry': usedDefaultExpiry,
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final payload = jsonDecode(response.body);
      final row = Map<String, dynamic>.from(payload['data'] ?? {});
      _cookingItems.insert(
        0,
        CookingCostItem(
          id: (row['id'] ?? row['_id']).toString(),
          name: (row['name'] ?? name).toString(),
          amountLabel: (row['amountLabel'] ?? amountLabel).toString(),
          price: ((row['price'] ?? price) as num).toDouble(),
          entryDate: DateTime.tryParse((row['entryDate'] ?? '').toString()) ?? entryDate,
          expiryDate: DateTime.tryParse((row['expiryDate'] ?? '').toString()) ?? expiryDate,
          usedDefaultExpiry: row['usedDefaultExpiry'] == true || usedDefaultExpiry,
        ),
      );
      notifyListeners();
      return;
    }

    throw Exception('Failed to save cooking item');
  }

  Future<void> removeCookingItem(String id) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/api/profile/cooking-items/$id'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove cooking item');
    }

    _cookingItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> addManualCost({
    required String title,
    required String category,
    required double amount,
    required DateTime date,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final response = await http.post(
      Uri.parse('$_apiBaseUrl/api/profile/manual-costs'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final payload = jsonDecode(response.body);
      final row = Map<String, dynamic>.from(payload['data'] ?? {});
      _manualEntries.insert(
        0,
        ManualCostEntry(
          id: (row['id'] ?? row['_id'] ?? _nextId()).toString(),
          title: (row['title'] ?? title).toString(),
          category: (row['category'] ?? category).toString(),
          amount: ((row['amount'] ?? amount) as num).toDouble(),
          date: DateTime.tryParse((row['date'] ?? '').toString()) ?? date,
        ),
      );
      notifyListeners();
      return;
    }

    throw Exception('Failed to save manual cost entry');
  }

  Future<void> removeManualCost(String id) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final response = await http.delete(
      Uri.parse('$_apiBaseUrl/api/profile/manual-costs/$id'),
      headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to remove manual cost entry');
    }

    _manualEntries.removeWhere((entry) => entry.id == id);
    notifyListeners();
  }

  bool _inRange(DateTime d, DateTime start, DateTime end) {
    final date = DateTime(d.year, d.month, d.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !date.isBefore(s) && !date.isAfter(e);
  }

  List<CookingCostItem> cookingInRange(DateTime start, DateTime end) {
    return _cookingItems.where((item) => _inRange(item.entryDate, start, end)).toList();
  }

  List<ManualCostEntry> manualInRange(DateTime start, DateTime end, {String category = 'All'}) {
    return _manualEntries.where((entry) {
      final matchesCategory = category == 'All' || entry.category == category;
      return matchesCategory && _inRange(entry.date, start, end);
    }).toList();
  }

  double totalInRange({
    required DateTime start,
    required DateTime end,
    bool includeCooking = true,
    bool includeManual = true,
    String category = 'All',
  }) {
    double total = 0;

    if (includeCooking && (category == 'All' || category == 'Food')) {
      total += cookingInRange(start, end).fold(0.0, (sum, item) => sum + item.price);
    }

    if (includeManual) {
      total += manualInRange(start, end, category: category).fold(0.0, (sum, entry) => sum + entry.amount);
    }

    return total;
  }

  double monthlyTotal({String category = 'All'}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);
    return totalInRange(start: start, end: end, category: category);
  }

  double yearlyTotal({String category = 'All'}) {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, 12, 31);
    return totalInRange(start: start, end: end, category: category);
  }

  Map<int, double> dailyBreakdown({
    required int year,
    required int month,
    bool includeCooking = true,
    bool includeManual = true,
    String category = 'All',
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final map = <int, double>{};

    for (var day = 1; day <= daysInMonth; day++) {
      final d = DateTime(year, month, day);
      map[day] = totalInRange(
        start: d,
        end: d,
        includeCooking: includeCooking,
        includeManual: includeManual,
        category: category,
      );
    }

    return map;
  }

  Map<int, double> weeklyBreakdown({
    required int year,
    required int month,
    bool includeCooking = true,
    bool includeManual = true,
    String category = 'All',
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final map = <int, double>{};

    for (var day = 1; day <= daysInMonth; day++) {
      final weekIndex = ((day - 1) ~/ 7) + 1;
      map[weekIndex] = (map[weekIndex] ?? 0) + totalInRange(
        start: DateTime(year, month, day),
        end: DateTime(year, month, day),
        includeCooking: includeCooking,
        includeManual: includeManual,
        category: category,
      );
    }

    return map;
  }

  Map<int, double> monthlyBreakdown({
    required int year,
    bool includeCooking = true,
    bool includeManual = true,
    String category = 'All',
  }) {
    final map = <int, double>{};
    for (var month = 1; month <= 12; month++) {
      map[month] = totalInRange(
        start: DateTime(year, month, 1),
        end: DateTime(year, month + 1, 0),
        includeCooking: includeCooking,
        includeManual: includeManual,
        category: category,
      );
    }
    return map;
  }
}
