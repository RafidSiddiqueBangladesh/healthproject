import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/food.dart';
import '../providers/cost_analysis_provider.dart';
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

class RoutineSuggestion {
  final String mealTime;
  final String meal;
  final String reason;

  const RoutineSuggestion({
    required this.mealTime,
    required this.meal,
    required this.reason,
  });
}

class AlternativeSuggestion {
  final String current;
  final String suggested;
  final String benefit;

  const AlternativeSuggestion({
    required this.current,
    required this.suggested,
    required this.benefit,
  });
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
  bool _isGeneratingAiInsights = false;
  String _spokenText = '';
  String _selectedAmount = 'Default';
  String _insightHeader = 'Demo AI plan shown. Add your foods/inventory for auto-updates.';
  String _lastInsightSignature = '';
  String _lastObservedSignature = '';

  List<RoutineSuggestion> _routineSuggestions = const [
    RoutineSuggestion(
      mealTime: 'Breakfast',
      meal: 'Oatmeal with banana and nuts',
      reason: 'Steady morning energy and fiber.',
    ),
    RoutineSuggestion(
      mealTime: 'Lunch',
      meal: 'Rice with vegetables and lentils',
      reason: 'Balanced carbs, micronutrients, and protein.',
    ),
    RoutineSuggestion(
      mealTime: 'Dinner',
      meal: 'Chicken or fish with salad',
      reason: 'Light protein-focused evening meal.',
    ),
    RoutineSuggestion(
      mealTime: 'Snack',
      meal: 'Yogurt and seasonal fruit',
      reason: 'Healthy snack with gut-friendly nutrients.',
    ),
  ];

  List<AlternativeSuggestion> _alternativeSuggestions = const [
    AlternativeSuggestion(
      current: 'Malta',
      suggested: 'Lemon',
      benefit: 'Higher vitamin C per cost in many markets.',
    ),
    AlternativeSuggestion(
      current: 'Chicken',
      suggested: 'Lentils',
      benefit: 'Budget-friendly protein swap for some meals.',
    ),
    AlternativeSuggestion(
      current: 'Premium greens',
      suggested: 'Spinach',
      benefit: 'Reliable iron source at lower cost.',
    ),
  ];

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://healthproject-ermg.onrender.com',
  );

  static const _amountOptions = <String>['Default', '1 piece', '1 cup', '100 g', '200 g', 'Custom grams', 'Custom pieces'];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Future.wait([
        context.read<NutritionProvider>().loadFoods(),
        context.read<CostAnalysisProvider>().loadCookingItems(),
      ]);
      if (!mounted) return;
      await _maybeRefreshAiInsights(force: true);
    });
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  String _signatureFromData(List<Food> foods, List<CookingCostItem> inventory) {
    final f = foods.map((e) => '${e.name.toLowerCase()}#${e.amountLabel.toLowerCase()}').join('|');
    final c = inventory.map((e) => '${e.name.toLowerCase()}#${e.amountLabel.toLowerCase()}').join('|');
    return 'foods:$f||inventory:$c';
  }

  String _stripMarkdownFences(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      final firstNewline = text.indexOf('\n');
      if (firstNewline >= 0) {
        text = text.substring(firstNewline + 1);
      }
      if (text.endsWith('```')) {
        text = text.substring(0, text.length - 3).trim();
      }
    }
    return text;
  }

  Map<String, dynamic>? _decodeObject(String raw) {
    final cleaned = _stripMarkdownFences(raw);
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final slice = cleaned.substring(start, end + 1);
      try {
        final decoded = jsonDecode(slice);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  List<RoutineSuggestion> _localRoutine(List<Food> foods, List<CookingCostItem> inventory) {
    final foodNames = foods.map((e) => e.name).take(4).toList();
    final inventoryNames = inventory.map((e) => e.name).take(4).toList();
    final topFood = foodNames.isNotEmpty ? foodNames.first : 'fruits';
    final topInventory = inventoryNames.isNotEmpty ? inventoryNames.first : 'vegetables';

    return [
      RoutineSuggestion(
        mealTime: 'Breakfast',
        meal: 'Use $topFood with oats or yogurt',
        reason: 'Easy, quick start using your recent intake pattern.',
      ),
      RoutineSuggestion(
        mealTime: 'Lunch',
        meal: 'Rice with $topInventory and lentils',
        reason: 'Uses available kitchen stock while staying balanced.',
      ),
      RoutineSuggestion(
        mealTime: 'Dinner',
        meal: 'Light protein with mixed salad',
        reason: 'Supports recovery and avoids heavy late meals.',
      ),
      RoutineSuggestion(
        mealTime: 'Snack',
        meal: 'Seasonal fruit plus nuts',
        reason: 'Low effort snack with better satiety.',
      ),
    ];
  }

  List<AlternativeSuggestion> _localAlternatives(List<Food> foods, List<CookingCostItem> inventory) {
    final names = [
      ...foods.map((e) => e.name.toLowerCase()),
      ...inventory.map((e) => e.name.toLowerCase()),
    ];

    final suggestions = <AlternativeSuggestion>[];

    if (names.any((n) => n.contains('chicken'))) {
      suggestions.add(
        const AlternativeSuggestion(
          current: 'Chicken (daily)',
          suggested: 'Lentils 2-3 days/week',
          benefit: 'Reduces cost while keeping protein intake stable.',
        ),
      );
    }

    if (names.any((n) => n.contains('rice'))) {
      suggestions.add(
        const AlternativeSuggestion(
          current: 'Large rice portion',
          suggested: 'Half rice + extra vegetables',
          benefit: 'Better fiber and easier calorie control.',
        ),
      );
    }

    if (names.any((n) => n.contains('banana') || n.contains('juice'))) {
      suggestions.add(
        const AlternativeSuggestion(
          current: 'Packaged juice/snack',
          suggested: 'Whole fruit + water',
          benefit: 'Less sugar spikes and usually cheaper.',
        ),
      );
    }

    suggestions.addAll(const [
      AlternativeSuggestion(
        current: 'Expensive citrus',
        suggested: 'Lemon',
        benefit: 'Good vitamin C at lower average cost.',
      ),
      AlternativeSuggestion(
        current: 'Processed snack',
        suggested: 'Roasted chickpeas',
        benefit: 'Higher protein and better fullness.',
      ),
    ]);

    return suggestions.take(3).toList();
  }

  Future<void> _maybeRefreshAiInsights({bool force = false}) async {
    if (!mounted || _isGeneratingAiInsights) return;

    final nutritionProvider = context.read<NutritionProvider>();
    final costProvider = context.read<CostAnalysisProvider>();
    final foods = nutritionProvider.foods;
    final inventory = costProvider.cookingItems;
    final signature = _signatureFromData(foods, inventory);

    if (!force && signature == _lastInsightSignature) return;
    _lastInsightSignature = signature;

    if (foods.isEmpty && inventory.isEmpty) {
      if (!mounted) return;
      setState(() {
        _insightHeader = 'Demo AI plan shown. Add your foods/inventory for auto-updates.';
        _routineSuggestions = _localRoutine(const [], const []);
        _alternativeSuggestions = _localAlternatives(const [], const []);
      });
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (!mounted) return;
      setState(() {
        _insightHeader = 'Smart plan based on your data (offline fallback).';
        _routineSuggestions = _localRoutine(foods, inventory);
        _alternativeSuggestions = _localAlternatives(foods, inventory);
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isGeneratingAiInsights = true;
      });
    }

    try {
      final foodLines = foods
          .take(10)
          .map((f) => '- ${f.name} (${f.amountLabel}, ${f.calories.toStringAsFixed(0)} kcal)')
          .join('\n');
      final inventoryLines = inventory
          .take(10)
          .map((i) => '- ${i.name} (${i.amountLabel}, ${i.price.toStringAsFixed(0)} taka)')
          .join('\n');

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
              'content': 'You are a nutrition and budget meal planner. Always return JSON only.',
            },
            {
              'role': 'user',
              'content': 'Create a personalized daily routine and food alternatives from these logs. '
                  'Return ONLY valid JSON with this schema: '
                  '{"headline":"...", "routine":[{"mealTime":"Breakfast","meal":"...","reason":"..."}], '
                  '"alternatives":[{"current":"...","suggested":"...","benefit":"..."}]} '
                  'Rules: routine length 4, alternatives length 3, short actionable text, no markdown.\n\n'
                  'Recent foods:\n$foodLines\n\nKitchen inventory:\n$inventoryLines',
            },
          ],
          'temperature': 0.3,
          'maxTokens': 600,
        }),
      ).timeout(const Duration(seconds: 16));

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final text = ((payload['data'] ?? const {})['text'] ?? '').toString();
        final map = _decodeObject(text);

        if (map != null) {
          final headline = (map['headline'] ?? '').toString().trim();
          final routineJson = List<Map<String, dynamic>>.from(map['routine'] ?? const []);
          final altJson = List<Map<String, dynamic>>.from(map['alternatives'] ?? const []);

          final routine = routineJson
              .map(
                (e) => RoutineSuggestion(
                  mealTime: (e['mealTime'] ?? 'Meal').toString(),
                  meal: (e['meal'] ?? '').toString(),
                  reason: (e['reason'] ?? '').toString(),
                ),
              )
              .where((e) => e.meal.trim().isNotEmpty)
              .take(4)
              .toList();

          final alternatives = altJson
              .map(
                (e) => AlternativeSuggestion(
                  current: (e['current'] ?? '').toString(),
                  suggested: (e['suggested'] ?? '').toString(),
                  benefit: (e['benefit'] ?? '').toString(),
                ),
              )
              .where((e) => e.current.trim().isNotEmpty && e.suggested.trim().isNotEmpty)
              .take(3)
              .toList();

          if (mounted && routine.isNotEmpty && alternatives.isNotEmpty) {
            setState(() {
              _insightHeader = headline.isNotEmpty
                  ? headline
                  : 'AI updated your plan using nutrition and cooking entries.';
              _routineSuggestions = routine;
              _alternativeSuggestions = alternatives;
            });
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _insightHeader = 'Smart plan based on your data (fallback mode).';
          _routineSuggestions = _localRoutine(foods, inventory);
          _alternativeSuggestions = _localAlternatives(foods, inventory);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _insightHeader = 'Smart plan based on your data (fallback mode).';
          _routineSuggestions = _localRoutine(foods, inventory);
          _alternativeSuggestions = _localAlternatives(foods, inventory);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingAiInsights = false;
        });
      }
    }
  }

  Future<void> _addMultipleFoods(List<FoodItem> foodItems) async {
    final provider = Provider.of<NutritionProvider>(context, listen: false);
    final userProvider = Provider.of<UserProvider>(context, listen: false);

    for (final item in foodItems) {
      if (item.name.trim().isEmpty) continue;

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
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added ${foods.length} food item(s)')),
          );
        } else {
          if (!mounted) return;
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
          if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NutritionProvider>(context);
    final costProvider = Provider.of<CostAnalysisProvider>(context);
    final observedSignature = _signatureFromData(provider.foods, costProvider.cookingItems);
    if (observedSignature != _lastObservedSignature) {
      _lastObservedSignature = observedSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeRefreshAiInsights();
      });
    }

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
          padding: const EdgeInsets.fromLTRB(16, 106, 16, 80),
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
                            final messenger = ScaffoldMessenger.of(context);
                            if (_controller.text.isNotEmpty) {
                              final foods = _parseMultipleFoods(_controller.text);
                              if (foods.isNotEmpty) {
                                await _addMultipleFoods(foods);
                                if (!mounted) return;
                                if (foods.length > 1) {
                                  messenger.showSnackBar(
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
              _buildDynamicRoutineCard(),
              const SizedBox(height: 20),
              _buildDynamicAlternativesCard(),
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
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await provider.removeFood(index);
                            } catch (_) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Could not delete food item')),
                              );
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

  Widget _buildDynamicRoutineCard() {
    return LiquidGlassCard(
      tint: const Color(0xFFAEEFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5DE8FF), Color(0xFF0C8BD8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI-Powered Daily Routine',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              if (_isGeneratingAiInsights)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x2AFFFFFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x45FFFFFF)),
            ),
            child: Text(
              _insightHeader,
              style: const TextStyle(
                color: Color(0xFFE6FBFF),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ..._routineSuggestions.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x22FFFFFF),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x5C0457A9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      item.mealTime,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.meal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.reason,
                          style: const TextStyle(color: Color(0xD6EEFBFF), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicAlternativesCard() {
    return LiquidGlassCard(
      tint: const Color(0xFFC8FFD6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF92F18C), Color(0xFF1B9E67)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Smart Alternatives',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._alternativeSuggestions.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: const Color(0x25FFFFFF),
                border: Border.all(color: const Color(0x36FFFFFF)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        const TextSpan(
                          text: 'Instead Of: ',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFE9FFE8)),
                        ),
                        TextSpan(text: item.current),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white),
                      children: [
                        const TextSpan(
                          text: 'Try: ',
                          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF1FFEE)),
                        ),
                        TextSpan(text: item.suggested),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.benefit,
                    style: const TextStyle(color: Color(0xE6F3FFF4), fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
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