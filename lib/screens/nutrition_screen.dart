import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/nutrition_provider.dart';
import '../services/food_matcher.dart';
import '../providers/user_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class FoodItem {
  final String name;
  final double price;
  
  FoodItem({required this.name, required this.price});
}

class NutritionTracker extends StatefulWidget {
  @override
  _NutritionTrackerState createState() => _NutritionTrackerState();
}

class _NutritionTrackerState extends State<NutritionTracker> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final ImagePicker _imagePicker = ImagePicker();
  bool _isListening = false;
  bool _isAnalyzingImage = false;
  String _spokenText = '';
  String _selectedAmount = 'Default';
  static const String _apiBaseUrl = 'http://localhost:5000';

  static const _amountOptions = <String>['Default', '1 piece', '1 cup', '100 g', '200 g', 'Custom grams', 'Custom pieces'];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NutritionProvider>().loadFoods();
    });
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  Future<void> _addMultipleFoods(List<FoodItem> foodItems) async {
    for (final item in foodItems) {
      if (item.name.trim().isEmpty) continue;
      
      final provider = Provider.of<NutritionProvider>(context, listen: false);
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      double? customGrams;
      if (_selectedAmount == 'Custom grams') {
        customGrams = double.tryParse(_gramsController.text.trim());
      } else if (_selectedAmount == 'Custom pieces') {
        final pieces = double.tryParse(_piecesController.text.trim()) ?? 1;
        customGrams = pieces * 100;
      } else if (_selectedAmount == '1 piece') {
        customGrams = 100;
      }

      final food = FoodMatcher.buildFoodFromInput(
        input: item.name,
        amountOption: _selectedAmount,
        customGrams: customGrams,
      );
      
      // Add detected price to food
      food.price = item.price;

      try {
        await provider.addFood(food);
        userProvider.addPoints(5);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not save some food items')),
          );
        }
      }
    }

    _controller.clear();
    if (_selectedAmount == 'Custom grams') {
      _gramsController.clear();
    } else if (_selectedAmount == 'Custom pieces') {
      _piecesController.clear();
    }
  }

  void _listen() async {
    if (!_isListening) {
      try {
        final available = await _speech.listen(
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _spokenText = result.recognizedWords;
              _controller.text = result.recognizedWords;
            });
          },
        );
        if (available == true) {
          setState(() => _isListening = true);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone not available')),
          );
        }
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
      
      if (_spokenText.isNotEmpty) {
        // Parse multiple foods from voice input
        final foods = _parseMultipleFoods(_spokenText);
        if (foods.isNotEmpty) {
          await _addMultipleFoods(foods);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${foods.length} food item(s)')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not detect food and price pairs from voice input')),
          );
        }
        _spokenText = '';
      }
    }
  }

  List<FoodItem> _parseMultipleFoodsWithPrices(String input) {
    final cleaned = input.replaceAll('\n', ' ').trim();
    final priced = _extractPricedFoods(cleaned);
    if (priced.isNotEmpty) return priced;

    if (_hasPriceSignal(cleaned)) {
      return const <FoodItem>[];
    }

    return _parseSimpleFoods(cleaned)
        .map((name) => FoodItem(name: name, price: 0.0))
        .toList();
  }

  bool _hasPriceSignal(String input) {
    final hasCurrency = RegExp(r'\b(taka|tk|৳|bdt|usd|\$)\b', caseSensitive: false).hasMatch(input);
    final hasNumber = RegExp(r'\d+(?:\.\d+)?').hasMatch(input);
    return hasCurrency || hasNumber;
  }

  List<FoodItem> _extractPricedFoods(String input) {
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    final items = <FoodItem>[];
    final seenNames = <String>{};

    final pattern = RegExp(
      r'([^,;]+?)\s+(\d+(?:\.\d+)?)\s*(?:taka|tk|৳|bdt|usd|\$)',
      caseSensitive: false,
    );

    for (final m in pattern.allMatches(normalized)) {
      final rawName = (m.group(1) ?? '').trim();
      final price = double.tryParse((m.group(2) ?? '').trim()) ?? 0.0;
      final itemName = _sanitizeFoodName(rawName);
      if (itemName.isEmpty || price <= 0 || seenNames.contains(itemName)) continue;
      items.add(FoodItem(name: itemName, price: price));
      seenNames.add(itemName);
    }

    return items;
  }

  String _sanitizeFoodName(String rawName) {
    final withoutQty = rawName
        .toLowerCase()
        .replaceAll(RegExp(r'\b\d+\s*(piece|pieces|pcs|pc|g|gram|grams|kg|l|liter|liters)?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(and|with)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return withoutQty;
  }

  List<FoodItem> _parseMultipleFoods(String input) {
    return _parseMultipleFoodsWithPrices(input);
  }

  List<String> _parseSimpleFoods(String input) {
    // Split by comma, "and", or spaces to detect multiple foods
    final cleaned = input.toLowerCase().trim();
    
    // First try splitting by comma
    if (cleaned.contains(',')) {
      return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    
    // Try splitting by " and "
    if (cleaned.contains(' and ')) {
      return cleaned.split(' and ').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    
    // Try splitting by spaces (for "rice potato hen" → ["rice", "potato", "hen"])
    final words = cleaned.split(RegExp(r'\s+'));
    final stopWords = {'a', 'an', 'the', 'with', 'or', 'of', 'in', 'on', 'at', 'to', 'for'};
    final filtered = words.where((w) => w.isNotEmpty && !stopWords.contains(w)).toList();
    
    // If we have multiple words (likely multiple foods), return them all
    if (filtered.length > 1) {
      return filtered;
    }
    
    // If single item, return as is
    return filtered.isNotEmpty ? filtered : [input];
  }

  Future<void> _pickFromCameraOrGallery() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );

    if (picked == null) return;
    await _detectFoodFromImage(picked);
  }

  String _mimeFromPath(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  String _normalizeFoodName(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'```[\s\S]*?```'), '')
        .replaceAll(RegExp("^[\"'\\s]+|[\"'\\s]+\$"), '')
        .split('\n')
        .first
        .trim();
    return cleaned;
  }

  Future<void> _detectFoodFromImage(XFile picked) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() => _isAnalyzingImage = true);
    }

    try {
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);
      final mime = _mimeFromPath(picked.path);

      final response = await http.post(
        Uri.parse('$_apiBaseUrl/api/ai/chat'),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'messages': [
            {
              'role': 'system',
              'content': 'You are a food price analyzer. Identify ALL food items AND their prices from the image. Format: "item1 price1 taka, item2 price2 taka". Extract numeric prices before currency words (taka, tk, ৳, \$, usd, bdt). If multiple foods, list all with prices. If no foods found, reply with "not detected". No explanation.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'Extract all foods and their prices from this image. Format as: egg 100 taka, banana 200 taka'},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:$mime;base64,$base64Image'}
                }
              ]
            }
          ],
          'temperature': 0.0,
          'maxTokens': 200,
        }),
      );

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final text = ((payload['data'] ?? const {})['text'] ?? '').toString();
        final detected = _normalizeFoodName(text);

        // Check if detection failed
        if (detected.toLowerCase().contains('not detected') || detected.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Try again - food not detected')),
            );
          }
          return;
        }

        // Parse multiple foods from image detection
        final foods = _parseMultipleFoods(detected);
        
        if (foods.isNotEmpty && mounted) {
          await _addMultipleFoods(foods);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Detected and added ${foods.length} food item(s)')),
          );
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Try again - food not detected')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Try again - food not detected')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Try again - food not detected')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
      }
    }
  }

  Future<void> _addFoodEntry(String rawInput) async {
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

    try {
      await provider.addFood(food);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save food item to database')),
        );
      }
      return;
    }
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
                          onPressed: _isAnalyzingImage ? null : _pickFromCameraOrGallery,
                          tooltip: 'OCR Scan',
                          style: IconButton.styleFrom(backgroundColor: const Color(0x3DFFFFFF)),
                        ),
                        if (_isAnalyzingImage) ...[
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () async {
                            if (_controller.text.isNotEmpty) {
                              final foods = _parseMultipleFoods(_controller.text);
                              if (foods.isNotEmpty) {
                                await _addMultipleFoods(foods);
                                if (mounted && foods.length > 1) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Added ${foods.length} food item(s)')),
                                  );
                                }
                              }
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
                          onPressed: () async {
                            try {
                              await provider.removeFood(index);
                            } catch (_) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Could not delete food item')),
                                );
                              }
                            }
                          },
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