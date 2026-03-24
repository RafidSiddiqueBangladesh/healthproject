import 'package:flutter/material.dart';

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

  List<CookingCostItem> get cookingItems => List.unmodifiable(_cookingItems);
  List<ManualCostEntry> get manualEntries => List.unmodifiable(_manualEntries);

  String _nextId() => DateTime.now().microsecondsSinceEpoch.toString();

  void addCookingItem({
    required String name,
    required String amountLabel,
    required double price,
    required DateTime entryDate,
    required DateTime expiryDate,
    required bool usedDefaultExpiry,
  }) {
    _cookingItems.add(
      CookingCostItem(
        id: _nextId(),
        name: name,
        amountLabel: amountLabel,
        price: price,
        entryDate: entryDate,
        expiryDate: expiryDate,
        usedDefaultExpiry: usedDefaultExpiry,
      ),
    );
    notifyListeners();
  }

  void removeCookingItem(String id) {
    _cookingItems.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void addManualCost({
    required String title,
    required String category,
    required double amount,
    required DateTime date,
  }) {
    _manualEntries.add(
      ManualCostEntry(
        id: _nextId(),
        title: title,
        category: category,
        amount: amount,
        date: date,
      ),
    );
    notifyListeners();
  }

  void removeManualCost(String id) {
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
}
