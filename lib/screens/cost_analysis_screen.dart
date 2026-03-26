import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/cost_analysis_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class CostAnalysisScreen extends StatefulWidget {
  const CostAnalysisScreen({super.key});

  @override
  State<CostAnalysisScreen> createState() => _CostAnalysisScreenState();
}

class _CostAnalysisScreenState extends State<CostAnalysisScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  static const _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static const _categoryOptions = <String>['All', 'Food', 'Nutrition'];

  late int _selectedMonth;
  late int _selectedYear;
  String _selectedCategory = 'All';
  String _newCategory = 'Food';
  bool _includeCookingData = true;
  bool _includeManualData = true;
  DateTime _newCostDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CostAnalysisProvider>();
      provider.loadCookingItems();
      provider.loadManualCosts();
    });
  }

  Future<void> _pickNewCostDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newCostDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      setState(() => _newCostDate = picked);
    }
  }

  Future<void> _addManualCost(BuildContext context) async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid title and amount.')),
      );
      return;
    }

    try {
      await context.read<CostAnalysisProvider>().addManualCost(
            title: title,
            category: _newCategory,
            amount: amount,
            date: _newCostDate,
          );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save manual cost entry to backend.')),
      );
      return;
    }

    _titleController.clear();
    _amountController.clear();
  }

  String _dateText(DateTime d) => '${d.day}/${d.month}/${d.year}';

  DateTimeRange _selectedMonthRange() {
    return DateTimeRange(
      start: DateTime(_selectedYear, _selectedMonth, 1),
      end: DateTime(_selectedYear, _selectedMonth + 1, 0),
    );
  }

  List<int> _yearOptions() {
    final now = DateTime.now().year;
    return List<int>.generate(10, (i) => now - 5 + i);
  }

  DateTimeRange _currentWeekRange() {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    return DateTimeRange(start: DateTime(start.year, start.month, start.day), end: DateTime(end.year, end.month, end.day));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostAnalysisProvider>();
    final monthRange = _selectedMonthRange();
    final yearRange = DateTimeRange(start: DateTime(_selectedYear, 1, 1), end: DateTime(_selectedYear, 12, 31));
    final weekRange = _currentWeekRange();
    final today = DateTime.now();

    final selectedMonthTotal = provider.totalInRange(
      start: monthRange.start,
      end: monthRange.end,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );
    final selectedYearTotal = provider.totalInRange(
      start: yearRange.start,
      end: yearRange.end,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );
    final thisWeekTotal = provider.totalInRange(
      start: weekRange.start,
      end: weekRange.end,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );
    final todayTotal = provider.totalInRange(
      start: today,
      end: today,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );

    final dailyBreakdown = provider.dailyBreakdown(
      year: _selectedYear,
      month: _selectedMonth,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );
    final weeklyBreakdown = provider.weeklyBreakdown(
      year: _selectedYear,
      month: _selectedMonth,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );
    final monthlyBreakdown = provider.monthlyBreakdown(
      year: _selectedYear,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );

    final cookingItems = provider.cookingInRange(monthRange.start, monthRange.end);
    final manualItems = provider.manualInRange(monthRange.start, monthRange.end, category: _selectedCategory);

    final showCooking = _includeCookingData && (_selectedCategory == 'All' || _selectedCategory == 'Food');
    final showManual = _includeManualData;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Cost Analysis',
          icon: Icons.analytics_rounded,
        ),
      ),
      body: LiquidGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiquidGlassCard(
                tint: const Color(0xFFFEDFC6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Analyze Costs',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedMonth,
                            items: List<DropdownMenuItem<int>>.generate(
                              12,
                              (i) => DropdownMenuItem<int>(value: i + 1, child: Text(_monthNames[i])),
                            ),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedMonth = value);
                            },
                            decoration: const InputDecoration(labelText: 'Month'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedYear,
                            items: _yearOptions()
                                .map((y) => DropdownMenuItem<int>(value: y, child: Text(y.toString())))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _selectedYear = value);
                            },
                            decoration: const InputDecoration(labelText: 'Year'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selected: ${_monthNames[_selectedMonth - 1]} $_selectedYear',
                      style: const TextStyle(color: Color(0xFFEAF6FF)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final now = DateTime.now();
                              setState(() {
                                _selectedMonth = now.month;
                                _selectedYear = now.year;
                              });
                            },
                            icon: const Icon(Icons.today),
                            label: const Text('Use Current'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              provider.loadCookingItems();
                              provider.loadManualCosts();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Data'),
                          ),
                        ),
                      ],
                    ),
                    if (provider.isLoadingCookingItems || provider.isLoadingManualItems) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(minHeight: 6),
                    ],
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: _categoryOptions
                          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedCategory = value);
                      },
                      decoration: const InputDecoration(labelText: 'Category Filter'),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      value: _includeCookingData,
                      onChanged: (v) => setState(() => _includeCookingData = v),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include Cooking Inventory Data'),
                    ),
                    SwitchListTile(
                      value: _includeManualData,
                      onChanged: (v) => setState(() => _includeManualData = v),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Include Manual Cost Entries'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                tint: const Color(0xFFA3FFE1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Calculated Totals',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Month Total: ${selectedMonthTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text('Year Total: ${selectedYearTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEFFFFA))),
                    Text('This Week: ${thisWeekTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEFFFFA))),
                    Text('Today: ${todayTotal.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEFFFFA))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                tint: const Color(0xFFBEDCFF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add New Cost',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title (example: Vitamins)'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Amount'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _newCategory,
                      items: const [
                        DropdownMenuItem(value: 'Food', child: Text('Food')),
                        DropdownMenuItem(value: 'Nutrition', child: Text('Nutrition')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _newCategory = value);
                      },
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _pickNewCostDate,
                      icon: const Icon(Icons.calendar_today),
                      label: Text('Date: ${_dateText(_newCostDate)}'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _addManualCost(context),
                      child: const Text('Add Cost Entry'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LiquidGlassCard(
                tint: const Color(0xFFD7E9FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Breakdown (${_monthNames[_selectedMonth - 1]} $_selectedYear)',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    ...dailyBreakdown.entries.where((e) => e.value > 0).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('Day ${e.key}: ${e.value.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEAF6FF))),
                          ),
                        ),
                    if (dailyBreakdown.values.every((v) => v <= 0))
                      const Text('No daily entries for selected month.', style: TextStyle(color: Color(0xFFEAF6FF))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LiquidGlassCard(
                tint: const Color(0xFFD6FFE8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Breakdown (${_monthNames[_selectedMonth - 1]} $_selectedYear)',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    ...weeklyBreakdown.entries.where((e) => e.value > 0).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('Week ${e.key}: ${e.value.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEAF6FF))),
                          ),
                        ),
                    if (weeklyBreakdown.values.every((v) => v <= 0))
                      const Text('No weekly entries for selected month.', style: TextStyle(color: Color(0xFFEAF6FF))),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              LiquidGlassCard(
                tint: const Color(0xFFF1D7FF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monthly Breakdown ($_selectedYear)',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    ...monthlyBreakdown.entries.where((e) => e.value > 0).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('${_monthNames[e.key - 1]}: ${e.value.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEAF6FF))),
                          ),
                        ),
                    if (monthlyBreakdown.values.every((v) => v <= 0))
                      const Text('No monthly entries for selected year.', style: TextStyle(color: Color(0xFFEAF6FF))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Data Used For Analysis (Selected Month)',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              if (!showCooking && !showManual)
                const LiquidGlassCard(
                  tint: Color(0xFFFFD6D6),
                  child: Text('Enable at least one data source to analyze costs.'),
                ),
              if (showCooking)
                ...cookingItems.map(
                  (item) => LiquidGlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    tint: const Color(0xFFDFFFE8),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.kitchen_rounded, color: Color(0xFFE8FFF8)),
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text(
                        '${item.amountLabel} • ${item.price.toStringAsFixed(2)} • ${_dateText(item.entryDate)}',
                        style: const TextStyle(color: Color(0xD8E6FDF9)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Color(0xFFFFD5D5)),
                        onPressed: () => provider.removeCookingItem(item.id),
                      ),
                    ),
                  ),
                ),
              if (showManual)
                ...manualItems.map(
                  (entry) => LiquidGlassCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    tint: const Color(0xFFF7DCFF),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_rounded, color: Color(0xFFE8FFF8)),
                      title: Text(entry.title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text(
                        '${entry.category} • ${entry.amount.toStringAsFixed(2)} • ${_dateText(entry.date)}',
                        style: const TextStyle(color: Color(0xD8E6FDF9)),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Color(0xFFFFD5D5)),
                        onPressed: () async {
                          try {
                            await provider.removeManualCost(entry.id);
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to delete manual cost entry.')),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
