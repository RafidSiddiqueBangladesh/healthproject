import 'dart:ui_web' as ui_web;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;
import 'package:webview_flutter/webview_flutter.dart';
import '../providers/cost_analysis_provider.dart';
import '../widgets/beautified_tab_heading.dart';
import '../widgets/liquid_glass.dart';

class InventoryItem {
  final String name;
  final double price;
  final String? amountLabel;
  
  InventoryItem({required this.name, required this.price, this.amountLabel});
}

class CookingScreen extends StatefulWidget {
  @override
  _CookingScreenState createState() => _CookingScreenState();
}

class _CookingScreenState extends State<CookingScreen> {
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _voiceController = TextEditingController();
  final TextEditingController _gramsController = TextEditingController();
  final TextEditingController _piecesController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final ImagePicker _imagePicker = ImagePicker();
  final Set<String> _registeredWebViewTypes = <String>{};
  final Map<String, String> _recipeVideoIds = <String, String>{};
  final Set<String> _loadingRecipeVideos = <String>{};
  final Set<String> _failedRecipeVideos = <String>{};
  static const String _apiBaseUrl = 'http://localhost:5000';

  bool _isListening = false;
  bool _isVoiceEntryMode = false;
  bool _isAnalyzingImage = false;
  String _spokenText = '';
  String _selectedAmount = 'Default';
  DateTime? _selectedExpiryDate;
  String _suggestion = 'Add inventory items to get smart cooking suggestions.';
  List<String> _recipes = [];
  int? _expandedRecipeIndex;

  String _recipeViewType(String videoId) {
    final safe = videoId.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]+'), '-');
    return 'cooking-youtube-$safe';
  }

  Future<void> _ensureRecipeVideo(String recipeName) async {
    if (_recipeVideoIds.containsKey(recipeName) || _loadingRecipeVideos.contains(recipeName)) {
      return;
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    setState(() {
      _loadingRecipeVideos.add(recipeName);
      _failedRecipeVideos.remove(recipeName);
    });

    try {
      final query = Uri.encodeQueryComponent('$recipeName recipe tutorial');
      final uri = Uri.parse('$_apiBaseUrl/api/ai/youtube/search?q=$query&maxResults=5');
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final payload = jsonDecode(response.body) as Map<String, dynamic>;
        final rows = List<Map<String, dynamic>>.from(payload['data'] ?? const []);
        final videoId = rows.isNotEmpty ? (rows.first['videoId'] ?? '').toString() : '';

        if (videoId.isNotEmpty && mounted) {
          setState(() {
            _recipeVideoIds[recipeName] = videoId;
            _failedRecipeVideos.remove(recipeName);
          });
        } else if (mounted) {
          setState(() {
            _failedRecipeVideos.add(recipeName);
          });
        }
      } else if (mounted) {
        setState(() {
          _failedRecipeVideos.add(recipeName);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failedRecipeVideos.add(recipeName);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRecipeVideos.remove(recipeName);
        });
      }
    }
  }

  static const _amountOptions = <String>['Default', '1 piece', '1 cup', '100 g', '200 g', 'Custom grams', 'Custom pieces'];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CostAnalysisProvider>().loadCookingItems();
    });
  }

  void _initSpeech() async {
    await _speech.initialize();
  }

  void _listen() async {
    if (!_isListening) {
      setState(() {
        _isVoiceEntryMode = true;
      });
      try {
        final available = await _speech.listen(
          onResult: (result) {
            if (!mounted) return;
            setState(() {
              _spokenText = result.recognizedWords;
              _voiceController.text = result.recognizedWords;
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
      await _speech.stop();
    }
  }

  Future<void> _addFromVoiceField() async {
    final voiceText = _voiceController.text.trim();
    if (voiceText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Voice input is empty')),
        );
      }
      return;
    }

    final ingredients = _parseMultipleIngredientsWithPrices(voiceText);
    if (ingredients.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not detect item and price pairs from voice input')),
        );
      }
      return;
    }

    await _addMultipleInventoryEntries(ingredients);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added ${ingredients.length} ingredient(s) from voice')),
    );
    setState(() {
      _spokenText = '';
      _voiceController.clear();
      _isVoiceEntryMode = false;
    });
  }

  DateTime _getDefaultExpiryDate(String itemName) {
    final now = DateTime.now();
    final nameLower = itemName.toLowerCase();

    if (nameLower.contains('meat') ||
        nameLower.contains('chicken') ||
        nameLower.contains('fish') ||
        nameLower.contains('???') ||
        nameLower.contains('????') ||
        nameLower.contains('?????')) {
      return now.add(const Duration(days: 90));
    } else if (nameLower.contains('vegetable') ||
        nameLower.contains('potato') ||
        nameLower.contains('?') ||
        nameLower.contains('????') ||
        nameLower.contains('???')) {
      return now.add(const Duration(days: 30));
    } else {
      return now.add(const Duration(days: 30));
    }
  }

  List<InventoryItem> _parseMultipleIngredientsWithPrices(String input) {
    final cleaned = input.replaceAll('\n', ' ').trim();
    final priced = _extractPricedIngredients(cleaned);
    if (priced.isNotEmpty) return priced;

    // If the user clearly spoke prices, do not silently create zero-price entries.
    if (_hasPriceSignal(cleaned)) {
      return const <InventoryItem>[];
    }

    return _parseSimpleIngredients(cleaned)
        .map((name) => InventoryItem(name: name, price: 0.0))
        .toList();
  }

  bool _hasPriceSignal(String input) {
    final hasCurrency = RegExp(r'\b(taka|tk|৳|bdt|usd|\$)\b', caseSensitive: false).hasMatch(input);
    final hasNumber = RegExp(r'\d+(?:\.\d+)?').hasMatch(input);
    return hasCurrency || hasNumber;
  }

  List<InventoryItem> _extractPricedIngredients(String input) {
    final normalized = input
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)(kg|g|gram|grams|pcs|pc|pieces|piece|l|liter|liters)\b', caseSensitive: false),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .replaceAllMapped(
          RegExp(r'(\d+(?:\.\d+)?)(taka|tk|৳|bdt|usd|\$)\b', caseSensitive: false),
          (m) => '${m.group(1)} ${m.group(2)}',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final items = <InventoryItem>[];
    var lastCurrencyMatchEnd = -1;

    // 1) Prefer explicit quantity + price + currency pairs:
    // "potato 2 kg 200 taka", "banana 6 pcs 300 taka"
    final withQtyAndCurrency = RegExp(
      r'([a-zA-Z\u0980-\u09FF][a-zA-Z\u0980-\u09FF\s-]*?)\s+(\d+(?:\.\d+)?)\s*(kg|g|gram|grams|pcs|pc|pieces|piece|l|liter|liters)\s+(\d+(?:\.\d+)?)\s*(?:taka|tk|৳|bdt|usd|\$)(?=\s*[a-zA-Z\u0980-\u09FF]|$|[,;])',
      caseSensitive: false,
    );

    for (final m in withQtyAndCurrency.allMatches(normalized)) {
      final rawName = (m.group(1) ?? '').trim();
      final qty = (m.group(2) ?? '').trim();
      final unit = (m.group(3) ?? '').trim().toLowerCase();
      final price = double.tryParse((m.group(4) ?? '').trim()) ?? 0.0;
      final itemName = _sanitizeIngredientName(rawName);
      final parsedAmount = _normalizedAmountLabel(qty, unit);
      if (itemName.isEmpty || price <= 0) continue;
      items.add(InventoryItem(name: itemName, price: price, amountLabel: parsedAmount));
      if (m.end > lastCurrencyMatchEnd) lastCurrencyMatchEnd = m.end;
    }

    // 2) Then explicit price + currency pairs without quantity: "potato 200 taka"
    final withCurrency = RegExp(
      r'([^,;]+?)\s+(\d+(?:\.\d+)?)\s*(?:taka|tk|৳|bdt|usd|\$)(?=\s*[a-zA-Z\u0980-\u09FF]|$|[,;])',
      caseSensitive: false,
    );

    for (final m in withCurrency.allMatches(normalized)) {
      final rawName = (m.group(1) ?? '').trim();
      final price = double.tryParse((m.group(2) ?? '').trim()) ?? 0.0;
      final inlineAmount = _extractInlineAmountLabel(rawName);
      final itemName = _sanitizeIngredientName(rawName);
      final hasInlineQty = RegExp(
        r'\d+\s*(kg|g|gram|grams|pcs|pc|pieces|piece|l|liter|liters)\b',
        caseSensitive: false,
      ).hasMatch(rawName);
      if (itemName.isEmpty || price <= 0) continue;
      if (hasInlineQty) continue;
      items.add(InventoryItem(name: itemName, price: price, amountLabel: inlineAmount));
      if (m.end > lastCurrencyMatchEnd) lastCurrencyMatchEnd = m.end;
    }

    // 3) Fallback for sequences without currency on every pair:
    //    "potato 200 banana 300"
    final trailing = lastCurrencyMatchEnd >= 0 && lastCurrencyMatchEnd < normalized.length
        ? normalized.substring(lastCurrencyMatchEnd).trim()
        : (items.isEmpty ? normalized : '');

    if (trailing.isNotEmpty) {
      final withoutCurrency = RegExp(
        r'([a-zA-Z\u0980-\u09FF][a-zA-Z\u0980-\u09FF\s-]*?)\s+(\d+(?:\.\d+)?)(?=\s+[a-zA-Z\u0980-\u09FF][a-zA-Z\u0980-\u09FF\s-]*?\s+\d+|$)',
        caseSensitive: false,
      );

      for (final m in withoutCurrency.allMatches(trailing)) {
        final rawName = (m.group(1) ?? '').trim();
        final price = double.tryParse((m.group(2) ?? '').trim()) ?? 0.0;
        final inlineAmount = _extractInlineAmountLabel(rawName);
        final itemName = _sanitizeIngredientName(rawName);
        if (itemName.isEmpty || price <= 0) continue;
        items.add(InventoryItem(name: itemName, price: price, amountLabel: inlineAmount));
      }
    }

    return items;
  }

  String? _extractInlineAmountLabel(String raw) {
    final m = RegExp(
      r'(\d+(?:\.\d+)?)\s*(kg|g|gram|grams|pcs|pc|pieces|piece|l|liter|liters)\b',
      caseSensitive: false,
    ).firstMatch(raw);
    if (m == null) return null;
    return _normalizedAmountLabel((m.group(1) ?? '').trim(), (m.group(2) ?? '').trim().toLowerCase());
  }

  String _normalizedAmountLabel(String qty, String unit) {
    final q = double.tryParse(qty);
    if (q == null) return 'Default';
    final compact = q % 1 == 0 ? q.toStringAsFixed(0) : q.toString();

    switch (unit) {
      case 'kg':
        return '$compact kg';
      case 'g':
      case 'gram':
      case 'grams':
        return '$compact g';
      case 'pcs':
      case 'pc':
      case 'piece':
      case 'pieces':
        return '$compact pcs';
      case 'l':
      case 'liter':
      case 'liters':
        return '$compact l';
      default:
        return 'Default';
    }
  }

  String _sanitizeIngredientName(String rawName) {
    final withoutQty = rawName
        .toLowerCase()
        .replaceAll(RegExp(r'\b\d+\s*(piece|pieces|pcs|pc|g|gram|grams|kg|l|liter|liters)?\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(taka|tk|৳|bdt|usd|\$)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\b(and|with)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[,;]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return withoutQty;
  }

  List<String> _parseMultipleIngredients(String input) {
    return _parseSimpleIngredients(input);
  }

  List<String> _parseSimpleIngredients(String input) {
    // Split by comma, "and", or spaces to detect multiple ingredients
    final cleaned = input.toLowerCase().trim();
    
    // First try splitting by comma
    if (cleaned.contains(',')) {
      return cleaned.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    
    // Try splitting by " and "
    if (cleaned.contains(' and ')) {
      return cleaned.split(' and ').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    
    // Try splitting by spaces (for "rice potato onion" → ["rice", "potato", "onion"])
    final words = cleaned.split(RegExp(r'\s+'));
    final stopWords = {'a', 'an', 'the', 'with', 'or', 'of', 'in', 'on', 'at', 'to', 'for'};
    final filtered = words.where((w) => w.isNotEmpty && !stopWords.contains(w)).toList();
    
    // If we have multiple words (likely multiple ingredients), return them all
    if (filtered.length > 1) {
      return filtered;
    }
    
    // If single item, return as is
    return filtered.isNotEmpty ? filtered : [input];
  }

  Future<void> _addMultipleInventoryEntries(List<InventoryItem> items) async {
    for (final item in items) {
      if (item.name.trim().isEmpty) continue;
      await _addInventoryEntry(item.name, price: item.price, amountLabel: item.amountLabel);
    }
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
    await _detectIngredientsFromImage(picked);
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

  Future<void> _detectIngredientsFromImage(XFile picked) async {
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
              'content': 'You are a receipt/price analyzer. Identify ALL ingredients or items AND their prices from the image. Format: "item1 price1 taka, item2 price2 taka". Extract numeric prices before currency words (taka, tk, ৳, \$, usd, bdt). If multiple items, list all with prices. If no items found, reply with "not detected". No explanation.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': 'Extract all ingredients and their prices from this image. Format as: egg 100 taka, banana 200 taka'},
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
              const SnackBar(content: Text('Try again - ingredients not detected')),
            );
          }
          return;
        }

        // Parse multiple ingredients with prices from image detection
        final ingredients = _parseMultipleIngredientsWithPrices(detected);
        
        if (ingredients.isNotEmpty && mounted) {
          _addMultipleInventoryEntries(ingredients);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Detected and added ${ingredients.length} ingredient(s)')),
          );
          _updateSuggestion();
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Try again - ingredients not detected')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Try again - ingredients not detected')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Try again - ingredients not detected')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingImage = false);
      }
    }
  }

  Future<void> _addInventoryEntry(String rawInput, {double price = 0.0, String? amountLabel}) async {
    final cleaned = rawInput.trim();
    if (cleaned.isEmpty) return;

    String finalAmountLabel;
    if (amountLabel != null && amountLabel.trim().isNotEmpty) {
      finalAmountLabel = amountLabel;
    } else if (_selectedAmount == 'Custom grams') {
      finalAmountLabel = '${double.tryParse(_gramsController.text.trim())?.toStringAsFixed(0) ?? '0'} g';
    } else if (_selectedAmount == 'Custom pieces') {
      finalAmountLabel = '${double.tryParse(_piecesController.text.trim())?.toStringAsFixed(0) ?? '1'} pcs';
    } else if (_selectedAmount == '1 piece') {
      finalAmountLabel = '1 piece';
    } else {
      finalAmountLabel = _selectedAmount;
    }

    final usedDefaultExpiry = _selectedExpiryDate == null;
    final expiryDate = _selectedExpiryDate ?? _getDefaultExpiryDate(cleaned);
    final entryDate = DateTime.now();
    // Use provided price if available, otherwise get from price controller
    final finalPrice = price > 0 ? price : (double.tryParse(_priceController.text.trim()) ?? 0);

    try {
      await context.read<CostAnalysisProvider>().addCookingItem(
            name: cleaned,
        amountLabel: finalAmountLabel,
            price: finalPrice,
            entryDate: entryDate,
            expiryDate: expiryDate,
            usedDefaultExpiry: usedDefaultExpiry,
          );

      if (!mounted) return;
      setState(() {
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
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save cooking item to database')),
        );
      }
    }
  }

  void _updateSuggestion() {
    final inventoryItems = context.read<CostAnalysisProvider>().cookingItems;
    final allText = inventoryItems.map((e) => e.name.toLowerCase()).join(' ');

    if (allText.contains('rice') || allText.contains('???')) {
      _suggestion = 'Cook rice with vegetables. Utilize leftovers for farming compost.';
      _recipes = ['Vegetable Fried Rice', 'Rice Porridge', 'Rice Salad'];
    } else if (allText.contains('chicken') || allText.contains('?????')) {
      _suggestion = 'Make chicken curry or stir-fry. Use bones for broth.';
      _recipes = ['Chicken Curry', 'Chicken Stir-Fry', 'Chicken Soup'];
    } else if (allText.contains('egg') || allText.contains('???')) {
      _suggestion = 'Egg-based meals are quick and budget friendly for any time of day.';
      _recipes = ['Egg Bhuna', 'Masala Omelette', 'Egg Fried Rice'];
    } else if (allText.contains('potato') || allText.contains('???')) {
      _suggestion = 'Potato can pair with almost anything. Add protein for a balanced meal.';
      _recipes = ['Potato Curry', 'Aloo Bhaji', 'Potato Soup'];
    } else {
      _suggestion = inventoryItems.isEmpty
          ? 'Add inventory items to get suggestions.'
          : 'Cook simple meals at low cost. Use food waste for organic farming.';
      _recipes = ['Simple Vegetable Stew', 'Basic Salad', 'Oatmeal'];
    }
    if (mounted) setState(() {});
  }

  Future<void> _removeInventoryItem(String id) async {
    try {
      await context.read<CostAnalysisProvider>().removeCookingItem(id);
      _updateSuggestion();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete cooking item')),
        );
      }
    }
  }

  int _daysLeft(DateTime expiryDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return target.difference(today).inDays;
  }

  Widget _buildRecipeVideoWidget(String videoId) {
    if (kIsWeb) {
      return _buildWebRecipeVideoWidget(videoId);
    }

    return Container(
      height: 200,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: WebViewWidget(
          controller: WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadRequest(Uri.parse('https://www.youtube.com/embed/$videoId?autoplay=0&modestbranding=1&rel=0')),
        ),
      ),
    );
  }

  Widget _buildWebRecipeVideoWidget(String videoId) {
    final viewType = _recipeViewType(videoId);
    final embedUrl = 'https://www.youtube.com/embed/$videoId?autoplay=0&modestbranding=1&rel=0';

    if (!_registeredWebViewTypes.contains(viewType)) {
      ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
        final iframe = web.HTMLIFrameElement()
          ..src = embedUrl
          ..style.border = '0'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allowFullscreen = true;
        return iframe;
      });
      _registeredWebViewTypes.add(viewType);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: HtmlElementView(viewType: viewType),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CostAnalysisProvider>();
    final inventoryItems = provider.cookingItems;

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
                          onPressed: _isAnalyzingImage ? null : _pickFromCameraOrGallery,
                          tooltip: 'Scan Receipt',
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
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async => _addInventoryEntry(_itemController.text),
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    if (_isVoiceEntryMode) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _voiceController,
                        decoration: InputDecoration(
                          labelText: 'Voice Entry (item qty unit price currency)',
                          prefixIcon: Icon(Icons.record_voice_over, color: Colors.orange[50]),
                          hintText: 'Example: potato 2 kg 200 taka banana 6 pcs 300 taka',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _addFromVoiceField,
                            icon: const Icon(Icons.playlist_add_check),
                            label: const Text('Add Voice Entries'),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: () {
                              _speech.stop();
                              setState(() {
                                _isVoiceEntryMode = false;
                                _isListening = false;
                                _voiceController.clear();
                                _spokenText = '';
                              });
                            },
                            child: const Text('Cancel Voice'),
                          ),
                        ],
                      ),
                    ],
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
                            items: _amountOptions.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
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
              const Text(
                'Smart Suggestions',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              LiquidGlassCard(
                tint: const Color(0xFFFFD6D6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
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
                const Text(
                  'Recipe Ideas',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                ..._recipes.asMap().entries.map(
                  (entry) {
                    final index = entry.key;
                    final recipe = entry.value;
                    final videoId = _recipeVideoIds[recipe];
                    final isLoadingVideo = _loadingRecipeVideos.contains(recipe);
                    final isVideoFailed = _failedRecipeVideos.contains(recipe);
                    final isExpanded = _expandedRecipeIndex == index;

                    return LiquidGlassCard(
                      margin: const EdgeInsets.only(bottom: 6),
                      borderRadius: 16,
                      tint: const Color(0xFFE3FFD8),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.restaurant, color: Color(0xFFEFFFF0)),
                            title: Text(recipe, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                            trailing: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: const Color(0xFFEFFFF0),
                            ),
                            onTap: () async {
                              final nextExpanded = isExpanded ? null : index;
                              setState(() {
                                _expandedRecipeIndex = nextExpanded;
                              });

                              if (nextExpanded != null && !_recipeVideoIds.containsKey(recipe)) {
                                await _ensureRecipeVideo(recipe);
                              }
                            },
                          ),
                          if (isExpanded) ...[
                            const SizedBox(height: 6),
                            if (videoId != null && videoId.isNotEmpty)
                              _buildRecipeVideoWidget(videoId)
                            else if (isVideoFailed)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Video unavailable. Tap retry.',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(height: 10),
                                    ElevatedButton.icon(
                                      onPressed: () => _ensureRecipeVideo(recipe),
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Retry Video'),
                                    ),
                                  ],
                                ),
                              )
                            else if (isLoadingVideo)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 20),
                                child: Center(child: CircularProgressIndicator()),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                child: ElevatedButton.icon(
                                  onPressed: () => _ensureRecipeVideo(recipe),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Load Recipe Video'),
                                ),
                              ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 20),
              LiquidGlassCard(
                tint: const Color(0xFFE2FFF9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
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
                                  'Expires: ${item.expiryDate.day}/${item.expiryDate.month}/${item.expiryDate.year} (${item.usedDefaultExpiry ? 'default' : 'selected'}) � ${daysLeft >= 0 ? '$daysLeft day(s) left' : '${daysLeft.abs()} day(s) overdue'}',
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
                              onPressed: () async => _removeInventoryItem(item.id),
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
    _voiceController.dispose();
    _gramsController.dispose();
    _piecesController.dispose();
    _priceController.dispose();
    _speech.stop();
    super.dispose();
  }
}
