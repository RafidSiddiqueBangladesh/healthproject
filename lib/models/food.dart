class Food {
  String name;
  double calories;
  String amountLabel;
  double grams;
  String? matchedReference;

  Food({
    required this.name,
    required this.calories,
    this.amountLabel = 'Default',
    this.grams = 0,
    this.matchedReference,
  });
}