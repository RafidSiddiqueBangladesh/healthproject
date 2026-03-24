import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/nutrition_provider.dart';
import '../services/food_matcher.dart';
import '../providers/user_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class NutritionTracker extends StatefulWidget {
  @override
  _NutritionTrackerState createState() => _NutritionTrackerState();
}

class _NutritionTrackerState extends State<NutritionTracker> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  String _spokenText = '';
  String _selectedAmount = 'Default';

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
      bool available = await _speech.listen(
        onResult: (result) => setState(() => _spokenText = result.recognizedWords),
      );
      if (available) {
        setState(() => _isListening = true);
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      if (_spokenText.isNotEmpty) {
        _addFoodEntry(_spokenText);
        _spokenText = '';
      }
    }
  }

  void _addFoodEntry(String rawInput) {
    if (rawInput.trim().isEmpty) {
      return;
    }

    final provider = Provider.of<NutritionProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    double? customGrams;
    if (_selectedAmount == 'Custom grams') {
      customGrams = double.tryParse(_gramsController.text.trim());
    } else if (_selectedAmount == 'Custom pieces') {
      // Convert pieces to grams (estimate: 1 piece ≈ 100g)
      final pieces = double.tryParse(_piecesController.text.trim()) ?? 1;
      customGrams = pieces * 100;
    } else if (_selectedAmount == '1 piece') {
      // 1 piece ≈ 100g
      customGrams = 100;
    }

    final food = FoodMatcher.buildFoodFromInput(
      input: rawInput,
      amountOption: _selectedAmount,
      customGrams: customGrams,
    );

    provider.addFood(food);
    userProvider.addPoints(5);
    _controller.clear();
    if (_selectedAmount == 'Custom grams') {
      _gramsController.clear();
    } else if (_selectedAmount == 'Custom pieces') {
      _piecesController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NutritionProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const BeautifiedTabHeading(
          title: 'Nutrition Tracker',
          icon: Icons.restaurant_menu_rounded,
        ),
      ),
      body: LiquidGlassBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 24),
          child: Column(
            children: [
              LiquidGlassCard(
                tint: const Color(0xFFFFE1B8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restaurant_menu, color: Colors.orange[100], size: 30),
                        const SizedBox(width: 10),
                        const Text(
                          'Add Food Item',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              labelText: 'Enter food name (English/Bangla)',
                              prefixIcon: Icon(Icons.edit, color: Colors.orange[50]),
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
                              const SnackBar(content: Text('OCR feature coming soon!')),
                            );
                          },
                          tooltip: 'OCR Scan',
                          style: IconButton.styleFrom(backgroundColor: const Color(0x3DFFFFFF)),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            if (_controller.text.isNotEmpty) {
                              _addFoodEntry(_controller.text);
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
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
                            decoration: const InputDecoration(
                              labelText: 'Amount Option',
                            ),
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
                    const SizedBox(height: 8),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Auto-match supports English and Bangla names. Empty amount uses default measure.',
                        style: TextStyle(fontSize: 12, color: Color(0xDCEFF8FF)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LiquidGlassCard(
                tint: const Color(0xFF8FFFE9),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0x40FFFFFF),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_fire_department, color: Color(0xFFFFE8AA), size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Calories Today',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE8FFFB)),
                          ),
                          Text(
                            '${provider.totalCalories.toStringAsFixed(1)} kcal',
                            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          Text(
                            '${provider.foods.length} food item(s) logged',
                            style: const TextStyle(fontSize: 12, color: Color(0xD5ECFFF8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LiquidGlassCard(
                tint: const Color(0xFFAEEFFF),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.schedule, color: Colors.lightBlue[50], size: 30),
                        const SizedBox(width: 10),
                        const Text(
                          'AI-Powered Daily Routine',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildRoutineItem('Breakfast', 'Oatmeal with fruits and nuts'),
                    _buildRoutineItem('Lunch', 'Rice with vegetables and pulses'),
                    _buildRoutineItem('Dinner', 'Fish or chicken with salad'),
                    _buildRoutineItem('Snacks', 'Yogurt, fruits, and nuts'),
                    const SizedBox(height: 15),
                    const Text(
                      'Tip: Stay hydrated and eat mindfully!',
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFFD7F4FF)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              LiquidGlassCard(
                tint: const Color(0xFFC8FFD6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.swap_horiz, color: Colors.green[50], size: 30),
                        const SizedBox(width: 10),
                        const Text(
                          'Smart Alternatives',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    _buildAlternativeItem('Vitamin C', 'Lemon instead of Malta (cheaper and healthier)'),
                    _buildAlternativeItem('Protein', 'Pulses instead of chicken (cost-effective)'),
                    _buildAlternativeItem('Iron', 'Spinach instead of expensive greens'),
                    const SizedBox(height: 15),
                    const Text(
                      'Save money while staying healthy!',
                      style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFFD9FFE2)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: provider.foods.length,
                  itemBuilder: (context, index) {
                    final food = provider.foods[index];
                    return LiquidGlassCard(
                      borderRadius: 18,
                      tint: const Color(0xFFE2FFF9),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        leading: const Icon(Icons.restaurant, color: Color(0xFFE8FFF8)),
                        title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        subtitle: Text(
                          '${food.calories.toStringAsFixed(1)} cal • ${food.amountLabel}',
                          style: const TextStyle(color: Color(0xD8E6FDF9)),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Color(0xFFFFD5D5)),
                          onPressed: () => provider.removeFood(index),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoutineItem(String time, String meal) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        children: [
          Text(time, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD9F4FF))),
          const SizedBox(width: 10),
          Expanded(child: Text(meal, style: const TextStyle(color: Color(0xF5FFFFFF)))),
        ],
      ),
    );
  }

  Widget _buildAlternativeItem(String nutrient, String alternative) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$nutrient:', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDEFFE9))),
          const SizedBox(width: 10),
          Expanded(child: Text(alternative, style: const TextStyle(color: Color(0xF5FFFFFF)))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _gramsController.dispose();
    _piecesController.dispose();
    _speech.stop();
    super.dispose();
  }
}