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

  static const _periodOptions = <String>['This Month', 'This Year', 'Custom Range'];
  static const _categoryOptions = <String>['All', 'Food', 'Nutrition'];

  String _selectedPeriod = 'This Month';
  String _selectedCategory = 'All';
  String _newCategory = 'Food';
  bool _includeCookingData = true;
  bool _includeManualData = true;
  DateTime? _customStart;
  DateTime? _customEnd;
  DateTime _newCostDate = DateTime.now();

  DateTimeRange _activeRange() {
    final now = DateTime.now();
    if (_selectedPeriod == 'This Year') {
      return DateTimeRange(
        start: DateTime(now.year, 1, 1),
        end: DateTime(now.year, 12, 31),
      );
    }
    if (_selectedPeriod == 'Custom Range' && _customStart != null && _customEnd != null) {
      return DateTimeRange(start: _customStart!, end: _customEnd!);
    }
    return DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (picked != null) {
      setState(() {
        _customStart = picked.start;
        _customEnd = picked.end;
      });
    }
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

  void _addManualCost(BuildContext context) {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid title and amount.')),
      );
      return;
    }

    context.read<CostAnalysisProvider>().addManualCost(
          title: title,
          category: _newCategory,
          amount: amount,
          date: _newCostDate,
        );

    _titleController.clear();
    _amountController.clear();
  }

  String _dateText(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostAnalysisProvider>();
    final range = _activeRange();

    final total = provider.totalInRange(
      start: range.start,
      end: range.end,
      includeCooking: _includeCookingData,
      includeManual: _includeManualData,
      category: _selectedCategory,
    );

    final monthlyFood = provider.monthlyTotal(category: 'Food');
    final yearlyFood = provider.yearlyTotal(category: 'Food');
    final monthlyNutrition = provider.monthlyTotal(category: 'Nutrition');
    final yearlyNutrition = provider.yearlyTotal(category: 'Nutrition');

    final cookingItems = provider.cookingInRange(range.start, range.end);
    final manualItems = provider.manualInRange(range.start, range.end, category: _selectedCategory);

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
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
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
                    DropdownButtonFormField<String>(
                      value: _selectedPeriod,
                      items: _periodOptions
                          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _selectedPeriod = value);
                      },
                      decoration: const InputDecoration(labelText: 'Time Range'),
                    ),
                    if (_selectedPeriod == 'Custom Range') ...[
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _pickCustomRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          _customStart != null && _customEnd != null
                              ? '${_dateText(_customStart!)} - ${_dateText(_customEnd!)}'
                              : 'Pick custom range',
                        ),
                      ),
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
                      'Totals',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Selected Range Total: ${total.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text('Monthly Food: ${monthlyFood.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEFFFFA))),
                    Text('Yearly Food: ${yearlyFood.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEFFFFA))),
                    Text('Monthly Nutrition: ${monthlyNutrition.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEFFFFA))),
                    Text('Yearly Nutrition: ${yearlyNutrition.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFEFFFFA))),
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
              const Text(
                'Data Used For Analysis',
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
                        onPressed: () => provider.removeManualCost(entry.id),
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
