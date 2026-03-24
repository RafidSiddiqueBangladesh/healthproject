import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/cost_analysis_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class CookingScreen extends StatefulWidget {
  @override
  _CookingScreenState createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final SpeechToText _speech = SpeechToText();

  bool _isListening = false;
  String _spokenText = '';
  String _selectedAmount = 'Default';
  DateTime? _selectedExpiryDate;
  String _suggestion = 'Add inventory items to get smart cooking suggestions.';
  List<String> _recipes = [];

  static const _amountOptions = <String>['Default', '1 piece', '1 cup', '100 g', '200 g', 'Custom grams', 'Custom pieces'];

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _listen() async {
    if (!_isListening) {
      final available = await _speech.listen(
        onResult: (result) => setState(() => _spokenText = result.recognizedWords),
      );
      if (available) {
        setState(() => _isListening = true);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_spokenText.isNotEmpty) {
        _addInventoryEntry(_spokenText);
        _spokenText = '';
      }
    }
  }

  DateTime _getDefaultExpiryDate(String itemName) {
    final now = DateTime.now();
    final nameLower = itemName.toLowerCase();
    
    // Meat and fish: 3 months
    if (nameLower.contains('meat') || nameLower.contains('chicken') || nameLower.contains('fish') ||
        nameLower.contains('মাছ') || nameLower.contains('মাংস') || nameLower.contains('মুরগি')) {
      return now.add(const Duration(days: 90));
    }
    // Vegetables: 1 month
    else if (nameLower.contains('vegetable') || nameLower.contains('potato') || nameLower.contains('প') ||
            nameLower.contains('সবজি') || nameLower.contains('আলু')) {
      return now.add(const Duration(days: 30));
    }
    // Default: 1 month
    else {
      return now.add(const Duration(days: 30));
    }
  }

  void _addInventoryEntry(String rawInput) {
    final cleaned = rawInput.trim();
    if (cleaned.isEmpty) {
      return;
    }

    String amountLabel;
    if (_selectedAmount == 'Custom grams') {
      amountLabel = '${double.tryParse(_gramsController.text.trim())?.toStringAsFixed(0) ?? '0'} g';
    } else if (_selectedAmount == 'Custom pieces') {
      amountLabel = '${double.tryParse(_piecesController.text.trim())?.toStringAsFixed(0) ?? '1'} pcs';
    } else if (_selectedAmount == '1 piece') {
      amountLabel = '1 piece';
    } else {
      amountLabel = _selectedAmount;
    }

    final usedDefaultExpiry = _selectedExpiryDate == null;
    final expiryDate = _selectedExpiryDate ?? _getDefaultExpiryDate(cleaned);
    final entryDate = DateTime.now();
    final price = double.tryParse(_priceController.text.trim()) ?? 0;

    setState(() {
      context.read<CostAnalysisProvider>().addCookingItem(
        name: cleaned,
        amountLabel: amountLabel,
        price: price,
        entryDate: entryDate,
        expiryDate: expiryDate,
        usedDefaultExpiry: usedDefaultExpiry,
      );
      _itemController.clear();
      _priceController.clear();
      if (_selectedAmount == 'Custom grams') {
        _gramsController.clear();
      } else if (_selectedAmount == 'Custom pieces') {
        _piecesController.clear();
      }
      _selectedExpiryDate = null;
    });

    _updateSuggestion();
  }

  void _updateSuggestion() {
    final inventoryItems = context.read<CostAnalysisProvider>().cookingItems;
    final allText = inventoryItems.map((e) => e.name.toLowerCase()).join(' ');

    if (allText.contains('rice') || allText.contains('ভাত')) {
      _suggestion = 'Cook rice with vegetables. Utilize leftovers for farming compost.';
      _recipes = ['Vegetable Fried Rice', 'Rice Porridge', 'Rice Salad'];
    } else if (allText.contains('chicken') || allText.contains('মুরগি')) {
      _suggestion = 'Make chicken curry or stir-fry. Use bones for broth.';
      _recipes = ['Chicken Curry', 'Chicken Stir-Fry', 'Chicken Soup'];
    } else if (allText.contains('egg') || allText.contains('ডিম')) {
      _suggestion = 'Egg-based meals are quick and budget friendly for any time of day.';
      _recipes = ['Egg Bhuna', 'Masala Omelette', 'Egg Fried Rice'];
    } else if (allText.contains('potato') || allText.contains('আলু')) {
      _suggestion = 'Potato can pair with almost anything. Add protein for a balanced meal.';
      _recipes = ['Potato Curry', 'Aloo Bhaji', 'Potato Soup'];
    } else {
      _suggestion = inventoryItems.isEmpty
          ? 'Add inventory items to get suggestions.'
          : 'Cook simple meals at low cost. Use food waste for organic farming.';
      _recipes = ['Simple Vegetable Stew', 'Basic Salad', 'Oatmeal'];
    }
    setState(() {});
  }

  void _removeInventoryItem(String id) {
    context.read<CostAnalysisProvider>().removeCookingItem(id);
    _updateSuggestion();
  }

  int _daysLeft(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return target.difference(today).inDays;
  }

  @override
  Widget build(BuildContext context) {
    final inventoryItems = context.watch<CostAnalysisProvider>().cookingItems;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Cooking Assistant',
          icon: Icons.kitchen,
        ),
      ),
      body: LiquidGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'What\'s in your kitchen?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              LiquidGlassCard(
                tint: const Color(0xFFFFE1B8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.kitchen, color: Colors.orange[50], size: 30),
                        const SizedBox(width: 10),
                        const Text('Inventory Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _itemController,
                            decoration: InputDecoration(
                              labelText: 'Enter ingredients (English/Bangla)',
                              prefixIcon: Icon(Icons.restaurant_menu_rounded, color: Colors.orange[50]),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.blue[50]),
                          onPressed: _listen,
                          tooltip: 'Voice Input',
                          style: IconButton.styleFrom(backgroundColor: const Color(0x3DFFFFFF)),
                        ),
                        IconButton(
                          icon: Icon(Icons.camera_alt, color: Colors.green[50]),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OCR scan coming soon!')),
                            );
                          },
                          tooltip: 'Scan Receipt',
                          style: IconButton.styleFrom(backgroundColor: const Color(0x3DFFFFFF)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _addInventoryEntry(_itemController.text),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Price',
                        prefixIcon: Icon(Icons.payments_rounded, color: Colors.orange[50]),
                        hintText: 'Example: 120',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedAmount,
                            items: _amountOptions
                                .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                _selectedAmount = value;
                              });
                            },
                            decoration: const InputDecoration(labelText: 'Amount Option'),
                          ),
                        ),
                        if (_selectedAmount == 'Custom grams' || _selectedAmount == 'Custom pieces') ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 130,
                            child: TextField(
                              controller: _selectedAmount == 'Custom pieces' ? _piecesController : _gramsController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: _selectedAmount == 'Custom pieces' ? 'pieces' : 'grams',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedExpiryDate ?? _getDefaultExpiryDate(_itemController.text),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (picked != null) {
                                setState(() => _selectedExpiryDate = picked);
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Expiry Date',
                                prefixIcon: Icon(Icons.calendar_today, color: Colors.orange[50]),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(
                                _selectedExpiryDate != null
                                    ? '${_selectedExpiryDate!.day}/${_selectedExpiryDate!.month}/${_selectedExpiryDate!.year}'
                                    : 'Tap to set (auto: default by type)',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Tip: Set expiry date or use auto-defaults (Meat/Fish: 3mo, Veg: 1mo).',
                        style: TextStyle(fontSize: 12, color: Color(0xDCEFF8FF)),
                      ),
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton(
                      onPressed: _updateSuggestion,
                      child: const Text('Get Cooking Ideas'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LiquidGlassCard(
                tint: const Color(0xFFA8FFE9),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0x40FFFFFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.inventory_2, color: Color(0xFFE3FFF8), size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventory Summary',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFEFFFFA)),
                          ),
                          Text(
                            '${inventoryItems.length} item(s) in kitchen',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Smart Suggestions',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              LiquidGlassCard(
                tint: const Color(0xFFFFD6D6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lightbulb, color: Color(0xFFFFF4BE), size: 30),
                        SizedBox(width: 10),
                        Text('Tip:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _suggestion,
                      style: const TextStyle(fontSize: 16, color: Color(0xF5FFFFFF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_recipes.isNotEmpty) ...[
                Text(
                  'Recipe Ideas',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                ..._recipes.map(
                  (recipe) => LiquidGlassCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    borderRadius: 16,
                    tint: const Color(0xFFE3FFD8),
                    child: ListTile(
                      leading: const Icon(Icons.restaurant, color: Color(0xFFEFFFF0)),
                      title: Text(recipe, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      trailing: const Icon(Icons.arrow_forward_ios, color: Color(0xFFEFFFF0)),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recipe details coming soon for $recipe!')));
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              LiquidGlassCard(
                tint: const Color(0xFFE2FFF9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.list_alt, color: Color(0xFFE8FFF8), size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Saved Inventory',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (inventoryItems.isEmpty)
                      const Text(
                        'No items yet. Add inventory above.',
                        style: TextStyle(color: Color(0xD8E6FDF9)),
                      )
                    else
                      ...List.generate(inventoryItems.length, (index) {
                        final item = inventoryItems[index];
                        final daysLeft = _daysLeft(item.expiryDate);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                            leading: const Icon(Icons.restaurant, color: Color(0xFFE8FFF8)),
                            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.amountLabel, style: const TextStyle(color: Color(0xD8E6FDF9))),
                                Text('Price: ${item.price.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xD8E6FDF9))),
                                Text(
                                  'Expires: ${item.expiryDate.day}/${item.expiryDate.month}/${item.expiryDate.year} (${item.usedDefaultExpiry ? 'default' : 'selected'}) • ${daysLeft >= 0 ? '$daysLeft day(s) left' : '${daysLeft.abs()} day(s) overdue'}',
                                  style: TextStyle(
                                    color: item.expiryDate.isBefore(DateTime.now().add(const Duration(days: 7)))
                                        ? const Color(0xFFFFB3B3)
                                        : const Color(0xFFB3FFB3),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Color(0xFFFFD5D5)),
                              onPressed: () => _removeInventoryItem(item.id),
                            ),
                          ),
                        );
                      }),
                  ],
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
    _itemController.dispose();
    _gramsController.dispose();
    _piecesController.dispose();
    _priceController.dispose();
    _speech.stop();
    super.dispose();
  }
}