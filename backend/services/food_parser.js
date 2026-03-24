const DEFAULT_CALORIES_PER_100G = {
  banana: 89,
  bread: 265,
  rice: 130,
  egg: 155,
  chicken: 239,
  potato: 77,
  apple: 52,
  milk: 42,
  fish: 206,
  lentil: 116,
  dal: 116
};

const DEFAULT_GRAMS_BY_UNIT = {
  piece: 50,
  pcs: 50,
  cup: 240,
  slice: 30,
  tablespoon: 15,
  tbsp: 15,
  teaspoon: 5,
  tsp: 5,
  bowl: 200,
  plate: 300,
  glass: 250,
  default: 100
};

function normalizeFoodName(name) {
  return String(name || '').trim().toLowerCase();
}

function estimateCalories(name, grams) {
  const key = normalizeFoodName(name);
  const calPer100g = DEFAULT_CALORIES_PER_100G[key] || 120;
  return Number(((grams * calPer100g) / 100).toFixed(1));
}

function parseLineFallback(line) {
  const cleaned = line.trim();
  if (!cleaned) return null;

  const match = cleaned.match(/^([\w\s\u0980-\u09FF\-]+?)\s*(\d+(?:\.\d+)?)?\s*(g|gram|grams|kg|piece|pcs|cup|slice|tbsp|tsp|ml|l)?$/i);
  if (!match) return null;

  const name = (match[1] || '').trim();
  if (!name) return null;

  const quantity = match[2] ? Number(match[2]) : null;
  let unit = (match[3] || '').toLowerCase();
  if (!unit) unit = 'default';

  let grams;
  if (unit === 'kg') {
    grams = quantity ? quantity * 1000 : DEFAULT_GRAMS_BY_UNIT.default;
  } else if (unit === 'g' || unit === 'gram' || unit === 'grams') {
    grams = quantity || DEFAULT_GRAMS_BY_UNIT.default;
  } else if (unit === 'ml') {
    grams = quantity || DEFAULT_GRAMS_BY_UNIT.default;
  } else if (unit === 'l') {
    grams = quantity ? quantity * 1000 : DEFAULT_GRAMS_BY_UNIT.default;
  } else {
    const perUnit = DEFAULT_GRAMS_BY_UNIT[unit] || DEFAULT_GRAMS_BY_UNIT.default;
    grams = quantity ? quantity * perUnit : perUnit;
  }

  return {
    name,
    quantity: quantity || 1,
    unit,
    grams: Number(grams.toFixed(1)),
    calories: estimateCalories(name, grams)
  };
}

function parseFoodItemsFallback(text) {
  const lines = String(text || '')
    .split(/\r?\n|,|;/)
    .map((line) => line.trim())
    .filter(Boolean);

  const items = [];
  for (const line of lines) {
    const parsed = parseLineFallback(line);
    if (parsed) items.push(parsed);
  }

  return items;
}

module.exports = {
  parseFoodItemsFallback,
  parseLineFallback,
  estimateCalories
};
