import '../models/food.dart';

class FoodReference {
  const FoodReference({
    required this.nameEn,
    required this.nameBn,
    required this.defaultMeasure,
    required this.defaultGrams,
    required this.defaultCalories,
    this.aliases = const [],
  });

  final String nameEn;
  final String nameBn;
  final String defaultMeasure;
  final double defaultGrams;
  final double defaultCalories;
  final List<String> aliases;

  double caloriesForGrams(double grams) {
    if (defaultGrams <= 0) {
      return defaultCalories;
    }
    return (defaultCalories / defaultGrams) * grams;
  }
}

class FoodMatchResult {
  const FoodMatchResult({required this.reference, required this.score});

  final FoodReference reference;
  final int score;
}

class FoodMatcher {
  static const List<FoodReference> _db = [
    FoodReference(nameEn: "Cow's milk, whole", nameBn: 'গরুর দুধ (ফুল ফ্যাট)', defaultMeasure: '1 cup', defaultGrams: 244, defaultCalories: 165, aliases: ['whole milk', 'milk']),
    FoodReference(nameEn: "Cow's milk, skim", nameBn: 'গরুর দুধ (স্কিম)', defaultMeasure: '1 cup', defaultGrams: 246, defaultCalories: 90, aliases: ['skim milk']),
    FoodReference(nameEn: 'Buttermilk', nameBn: 'বাটারমিল্ক', defaultMeasure: '1 cup', defaultGrams: 246, defaultCalories: 127),
    FoodReference(nameEn: 'Goat milk', nameBn: 'ছাগলের দুধ', defaultMeasure: '1 cup', defaultGrams: 244, defaultCalories: 165),
    FoodReference(nameEn: 'Yogurt', nameBn: 'দই', defaultMeasure: '1 cup', defaultGrams: 250, defaultCalories: 128, aliases: ['doi']),
    FoodReference(nameEn: 'Ice cream', nameBn: 'আইসক্রিম', defaultMeasure: '1 cup', defaultGrams: 188, defaultCalories: 300),
    FoodReference(nameEn: 'Cheddar cheese', nameBn: 'চেডার চিজ', defaultMeasure: '1 oz', defaultGrams: 28, defaultCalories: 110, aliases: ['cheese']),
    FoodReference(nameEn: 'Cottage cheese', nameBn: 'কটেজ চিজ', defaultMeasure: '1 cup', defaultGrams: 225, defaultCalories: 240),
    FoodReference(nameEn: 'Egg, boiled', nameBn: 'সিদ্ধ ডিম', defaultMeasure: '2 pcs', defaultGrams: 100, defaultCalories: 150, aliases: ['egg']),
    FoodReference(nameEn: 'Egg, fried/scrambled', nameBn: 'ভাজা/স্ক্র্যাম্বল ডিম', defaultMeasure: '2 pcs', defaultGrams: 128, defaultCalories: 220),

    FoodReference(nameEn: 'Butter', nameBn: 'মাখন', defaultMeasure: '1 tbsp', defaultGrams: 14, defaultCalories: 100),
    FoodReference(nameEn: 'Margarine', nameBn: 'মার্জারিন', defaultMeasure: '1 tbsp', defaultGrams: 14, defaultCalories: 100),
    FoodReference(nameEn: 'Mayonnaise', nameBn: 'মেয়োনিজ', defaultMeasure: '1 tbsp', defaultGrams: 15, defaultCalories: 110),
    FoodReference(nameEn: 'Olive oil', nameBn: 'অলিভ অয়েল', defaultMeasure: '1 tbsp', defaultGrams: 14, defaultCalories: 125, aliases: ['oil']),
    FoodReference(nameEn: 'Sunflower oil', nameBn: 'সূর্যমুখী তেল', defaultMeasure: '1 tbsp', defaultGrams: 14, defaultCalories: 125),

    FoodReference(nameEn: 'Beef, lean', nameBn: 'গরুর মাংস (লিন)', defaultMeasure: '3 oz', defaultGrams: 85, defaultCalories: 220, aliases: ['beef']),
    FoodReference(nameEn: 'Chicken, roasted', nameBn: 'রোস্টেড মুরগি', defaultMeasure: '3.5 oz', defaultGrams: 100, defaultCalories: 290, aliases: ['chicken', 'murgi']),
    FoodReference(nameEn: 'Chicken, broiled', nameBn: 'গ্রিল মুরগি', defaultMeasure: '3 oz', defaultGrams: 85, defaultCalories: 185),
    FoodReference(nameEn: 'Lamb chop', nameBn: 'খাসির চপ', defaultMeasure: '4 oz', defaultGrams: 115, defaultCalories: 480, aliases: ['mutton']),
    FoodReference(nameEn: 'Pork chop', nameBn: 'পর্ক চপ', defaultMeasure: '3.5 oz', defaultGrams: 100, defaultCalories: 260),
    FoodReference(nameEn: 'Turkey, roasted', nameBn: 'রোস্টেড টার্কি', defaultMeasure: '3.5 oz', defaultGrams: 100, defaultCalories: 265),
    FoodReference(nameEn: 'Sausage', nameBn: 'সসেজ', defaultMeasure: '3.5 oz', defaultGrams: 100, defaultCalories: 475),

    FoodReference(nameEn: 'Cod, broiled', nameBn: 'কড মাছ', defaultMeasure: '3.5 oz', defaultGrams: 100, defaultCalories: 170, aliases: ['cod']),
    FoodReference(nameEn: 'Salmon, canned', nameBn: 'স্যালমন মাছ', defaultMeasure: '3 oz', defaultGrams: 85, defaultCalories: 120, aliases: ['salmon']),
    FoodReference(nameEn: 'Tuna, canned', nameBn: 'টুনা মাছ', defaultMeasure: '3 oz', defaultGrams: 85, defaultCalories: 170, aliases: ['tuna']),
    FoodReference(nameEn: 'Shrimp, steamed', nameBn: 'চিংড়ি', defaultMeasure: '3 oz', defaultGrams: 85, defaultCalories: 110, aliases: ['prawn']),
    FoodReference(nameEn: 'Sardines', nameBn: 'সার্ডিন', defaultMeasure: '3 oz', defaultGrams: 85, defaultCalories: 180),

    FoodReference(nameEn: 'Rice, white (uncooked)', nameBn: 'সাদা চাল (কাঁচা)', defaultMeasure: '1 cup', defaultGrams: 191, defaultCalories: 692, aliases: ['rice', 'vat', 'ভাত']),
    FoodReference(nameEn: 'Brown rice (uncooked)', nameBn: 'ব্রাউন রাইস (কাঁচা)', defaultMeasure: '1 cup', defaultGrams: 208, defaultCalories: 748),
    FoodReference(nameEn: 'Oatmeal', nameBn: 'ওটমিল', defaultMeasure: '1 cup', defaultGrams: 236, defaultCalories: 150, aliases: ['oats']),
    FoodReference(nameEn: 'Bread, white', nameBn: 'সাদা পাউরুটি', defaultMeasure: '1 slice', defaultGrams: 23, defaultCalories: 60, aliases: ['bread', 'ruti', 'রুটি', 'পাউরুটি']),
    FoodReference(nameEn: 'Bread, whole-wheat', nameBn: 'আটা পাউরুটি', defaultMeasure: '1 slice', defaultGrams: 23, defaultCalories: 55),
    FoodReference(nameEn: 'Cornflakes', nameBn: 'কর্নফ্লেক্স', defaultMeasure: '1 cup', defaultGrams: 25, defaultCalories: 110),
    FoodReference(nameEn: 'Spaghetti with meat sauce', nameBn: 'স্প্যাগেটি (মিট সস)', defaultMeasure: '1 cup', defaultGrams: 250, defaultCalories: 285),
    FoodReference(nameEn: 'Pizza, cheese', nameBn: 'চিজ পিজ্জা', defaultMeasure: '1 slice', defaultGrams: 75, defaultCalories: 180, aliases: ['pizza']),

    FoodReference(nameEn: 'Potato, baked', nameBn: 'বেকড আলু', defaultMeasure: '1 medium', defaultGrams: 100, defaultCalories: 100, aliases: ['potato', 'alu', 'আলু']),
    FoodReference(nameEn: 'Potato fries', nameBn: 'ফ্রেঞ্চ ফ্রাই', defaultMeasure: '10 pcs', defaultGrams: 60, defaultCalories: 155, aliases: ['fries']),
    FoodReference(nameEn: 'Sweet potato', nameBn: 'মিষ্টি আলু', defaultMeasure: '1 medium', defaultGrams: 110, defaultCalories: 155),
    FoodReference(nameEn: 'Spinach, steamed', nameBn: 'পালং শাক', defaultMeasure: '1 cup', defaultGrams: 100, defaultCalories: 26, aliases: ['spinach']),
    FoodReference(nameEn: 'Broccoli, steamed', nameBn: 'ব্রোকলি', defaultMeasure: '1 cup', defaultGrams: 150, defaultCalories: 45),
    FoodReference(nameEn: 'Carrot, cooked', nameBn: 'গাজর', defaultMeasure: '1 cup', defaultGrams: 150, defaultCalories: 45, aliases: ['carrot']),
    FoodReference(nameEn: 'Cucumber', nameBn: 'শসা', defaultMeasure: '8 slices', defaultGrams: 50, defaultCalories: 6, aliases: ['cucumber']),
    FoodReference(nameEn: 'Tomato, raw', nameBn: 'টমেটো', defaultMeasure: '1 medium', defaultGrams: 150, defaultCalories: 30, aliases: ['tomato']),
    FoodReference(nameEn: 'Onion, raw', nameBn: 'পেঁয়াজ', defaultMeasure: '6 small', defaultGrams: 50, defaultCalories: 22, aliases: ['onion']),
    FoodReference(nameEn: 'Peas, fresh', nameBn: 'মটরশুঁটি', defaultMeasure: '1 cup', defaultGrams: 100, defaultCalories: 70, aliases: ['peas']),

    FoodReference(nameEn: 'Apple', nameBn: 'আপেল', defaultMeasure: '1 medium', defaultGrams: 130, defaultCalories: 70, aliases: ['apple']),
    FoodReference(nameEn: 'Banana', nameBn: 'কলা', defaultMeasure: '1 medium', defaultGrams: 150, defaultCalories: 85, aliases: ['banana']),
    FoodReference(nameEn: 'Orange', nameBn: 'কমলা', defaultMeasure: '1 medium', defaultGrams: 180, defaultCalories: 60, aliases: ['orange']),
    FoodReference(nameEn: 'Mango', nameBn: 'আম', defaultMeasure: '100 g', defaultGrams: 100, defaultCalories: 60, aliases: ['mango']),
    FoodReference(nameEn: 'Papaya', nameBn: 'পেঁপে', defaultMeasure: '1/2 medium', defaultGrams: 200, defaultCalories: 75),
    FoodReference(nameEn: 'Pineapple', nameBn: 'আনারস', defaultMeasure: '1 cup', defaultGrams: 140, defaultCalories: 75),
    FoodReference(nameEn: 'Watermelon', nameBn: 'তরমুজ', defaultMeasure: '1 wedge', defaultGrams: 925, defaultCalories: 120),
    FoodReference(nameEn: 'Grapes', nameBn: 'আঙুর', defaultMeasure: '1 cup', defaultGrams: 160, defaultCalories: 100),
    FoodReference(nameEn: 'Strawberries', nameBn: 'স্ট্রবেরি', defaultMeasure: '1 cup', defaultGrams: 149, defaultCalories: 54),

    FoodReference(nameEn: 'Soup, vegetable', nameBn: 'সবজি স্যুপ', defaultMeasure: '1 cup', defaultGrams: 250, defaultCalories: 80, aliases: ['vegetable soup']),
    FoodReference(nameEn: 'Soup, tomato with milk', nameBn: 'টমেটো স্যুপ (দুধসহ)', defaultMeasure: '1 cup', defaultGrams: 245, defaultCalories: 175),
    FoodReference(nameEn: 'Soup, chicken', nameBn: 'চিকেন স্যুপ', defaultMeasure: '1 cup', defaultGrams: 250, defaultCalories: 75),

    FoodReference(nameEn: 'Sugar', nameBn: 'চিনি', defaultMeasure: '1 tbsp', defaultGrams: 12, defaultCalories: 50, aliases: ['sugar']),
    FoodReference(nameEn: 'Honey', nameBn: 'মধু', defaultMeasure: '2 tbsp', defaultGrams: 42, defaultCalories: 120, aliases: ['honey']),
    FoodReference(nameEn: 'Chocolate', nameBn: 'চকোলেট', defaultMeasure: '2 oz', defaultGrams: 56, defaultCalories: 290, aliases: ['milk chocolate']),
    FoodReference(nameEn: 'Cake, plain', nameBn: 'কেক', defaultMeasure: '1 slice', defaultGrams: 55, defaultCalories: 180, aliases: ['cake']),
    FoodReference(nameEn: 'Doughnut', nameBn: 'ডোনাট', defaultMeasure: '1 pc', defaultGrams: 33, defaultCalories: 135, aliases: ['donut']),
    FoodReference(nameEn: 'Apple pie', nameBn: 'আপেল পাই', defaultMeasure: '1 slice', defaultGrams: 135, defaultCalories: 330),

    FoodReference(nameEn: 'Almonds', nameBn: 'কাঠবাদাম', defaultMeasure: '1/2 cup', defaultGrams: 70, defaultCalories: 425, aliases: ['almond']),
    FoodReference(nameEn: 'Cashews', nameBn: 'কাজু বাদাম', defaultMeasure: '1/2 cup', defaultGrams: 70, defaultCalories: 392, aliases: ['cashew']),
    FoodReference(nameEn: 'Peanuts', nameBn: 'চিনাবাদাম', defaultMeasure: '1/3 cup', defaultGrams: 50, defaultCalories: 290, aliases: ['peanut']),
    FoodReference(nameEn: 'Walnuts', nameBn: 'আখরোট', defaultMeasure: '1/2 cup', defaultGrams: 50, defaultCalories: 325, aliases: ['walnut']),
    FoodReference(nameEn: 'Sunflower seeds', nameBn: 'সূর্যমুখী বীজ', defaultMeasure: '1/2 cup', defaultGrams: 50, defaultCalories: 280),

    FoodReference(nameEn: 'Cola drink', nameBn: 'কোলা', defaultMeasure: '12 oz', defaultGrams: 346, defaultCalories: 137, aliases: ['cola', 'soft drink']),
    FoodReference(nameEn: 'Coffee, black', nameBn: 'ব্ল্যাক কফি', defaultMeasure: '1 cup', defaultGrams: 230, defaultCalories: 3, aliases: ['coffee']),
    FoodReference(nameEn: 'Tea, unsweetened', nameBn: 'চিনি ছাড়া চা', defaultMeasure: '1 cup', defaultGrams: 230, defaultCalories: 4, aliases: ['tea']),
    FoodReference(nameEn: 'Beer', nameBn: 'বিয়ার', defaultMeasure: '2 cups', defaultGrams: 480, defaultCalories: 228),
    FoodReference(nameEn: 'Wine, table', nameBn: 'ওয়াইন', defaultMeasure: '1/2 cup', defaultGrams: 120, defaultCalories: 100),
  ];

  static Food buildFoodFromInput({
    required String input,
    required String amountOption,
    required double? customGrams,
  }) {
    final query = input.trim();
    final match = _findBestMatch(query);

    if (match == null) {
      const fallbackCalories = 100.0;
      final grams = customGrams ?? 0;
      return Food(
        name: query,
        calories: fallbackCalories,
        amountLabel: customGrams != null ? '${customGrams.toStringAsFixed(0)} g' : 'Default',
        grams: grams,
        matchedReference: null,
      );
    }

    final ref = match.reference;
    final option = amountOption.trim();

    double grams;
    String label;

    if (customGrams != null && customGrams > 0) {
      grams = customGrams;
      label = '${customGrams.toStringAsFixed(0)} g';
    } else if (option == '100 g') {
      grams = 100;
      label = '100 g';
    } else if (option == '200 g') {
      grams = 200;
      label = '200 g';
    } else if (option == '1 cup') {
      if (ref.defaultMeasure.toLowerCase().contains('cup')) {
        grams = ref.defaultGrams;
      } else {
        grams = 240;
      }
      label = '1 cup';
    } else {
      grams = ref.defaultGrams;
      label = 'Default (${ref.defaultMeasure})';
    }

    final calories = ref.caloriesForGrams(grams);
    return Food(
      name: '${ref.nameEn} / ${ref.nameBn}',
      calories: double.parse(calories.toStringAsFixed(1)),
      amountLabel: label,
      grams: double.parse(grams.toStringAsFixed(1)),
      matchedReference: ref.nameEn,
    );
  }

  static FoodMatchResult? _findBestMatch(String query) {
    final q = _normalize(query);
    if (q.isEmpty) {
      return null;
    }

    FoodMatchResult? best;
    for (final ref in _db) {
      final score = _score(ref, q);
      if (score <= 0) {
        continue;
      }
      if (best == null || score > best.score) {
        best = FoodMatchResult(reference: ref, score: score);
      }
    }
    return best;
  }

  static int _score(FoodReference ref, String query) {
    final names = <String>[
      ref.nameEn,
      ref.nameBn,
      ...ref.aliases,
    ].map(_normalize).toList();

    for (final n in names) {
      if (n == query) {
        return 100;
      }
    }
    for (final n in names) {
      if (n.startsWith(query) || query.startsWith(n)) {
        return 80;
      }
    }
    for (final n in names) {
      if (n.contains(query) || query.contains(n)) {
        return 60;
      }
    }

    final queryWords = query.split(' ').where((e) => e.isNotEmpty).toList();
    int overlap = 0;
    for (final n in names) {
      for (final w in queryWords) {
        if (n.contains(w)) {
          overlap += 1;
        }
      }
    }
    return overlap > 0 ? 20 + overlap : 0;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\u0980-\u09FF\s]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
