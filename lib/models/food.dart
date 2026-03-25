class Food {
  String? id;
  String name;
  double calories;
  String amountLabel;
  double grams;
  String? matchedReference;
  DateTime? createdAt;
  double price;

  Food({
    this.id,
    required this.name,
    required this.calories,
    this.amountLabel = 'Default',
    this.grams = 0,
    this.matchedReference,
    this.createdAt,
    this.price = 0.0,
  });
}