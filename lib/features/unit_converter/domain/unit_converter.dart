/// Length / weight / volume / temperature conversions + NL parse.
class UnitConverter {
  static const lengthToMeter = <String, double>{
    'mm': 0.001,
    'cm': 0.01,
    'm': 1,
    'km': 1000,
    'in': 0.0254,
    'ft': 0.3048,
    'yd': 0.9144,
    'mi': 1609.344,
  };

  static const weightToKg = <String, double>{
    'mg': 0.000001,
    'g': 0.001,
    'kg': 1,
    't': 1000,
    'oz': 0.0283495,
    'lb': 0.453592,
  };

  static const volumeToLiter = <String, double>{
    'ml': 0.001,
    'l': 1,
    'L': 1,
    'gal': 3.78541,
    'qt': 0.946353,
    'cup': 0.236588,
    'fl_oz': 0.0295735,
  };

  /// Canonical unit id → display label.
  static const unitLabels = <String, String>{
    'mm': '밀리미터 (mm)',
    'cm': '센티미터 (cm)',
    'm': '미터 (m)',
    'km': '킬로미터 (km)',
    'in': '인치 (in)',
    'ft': '피트 (ft)',
    'yd': '야드 (yd)',
    'mi': '마일 (mi)',
    'mg': '밀리그램 (mg)',
    'g': '그램 (g)',
    'kg': '킬로그램 (kg)',
    't': '톤 (t)',
    'oz': '온스 (oz)',
    'lb': '파운드 (lb)',
    'ml': '밀리리터 (ml)',
    'l': '리터 (L)',
    'gal': '갤런 (gal)',
    'qt': '쿼트 (qt)',
    'cup': '컵 (cup)',
    'fl_oz': '액량온스 (fl oz)',
    'c': '섭씨 (°C)',
    'f': '화씨 (°F)',
  };

  /// Alias → canonical unit id (longest keys matched first in NL).
  static const unitAliases = <String, String>{
    // length
    'millimeter': 'mm',
    'millimetre': 'mm',
    '밀리미터': 'mm',
    'mm': 'mm',
    'centimeter': 'cm',
    'centimetre': 'cm',
    '센티미터': 'cm',
    '센티': 'cm',
    'cm': 'cm',
    'meter': 'm',
    'metre': 'm',
    'meters': 'm',
    'metres': 'm',
    '미터': 'm',
    'm': 'm',
    'kilometer': 'km',
    'kilometre': 'km',
    'kilometers': 'km',
    '킬로미터': 'km',
    'km': 'km',
    'inch': 'in',
    'inches': 'in',
    '인치': 'in',
    'in': 'in',
    'foot': 'ft',
    'feet': 'ft',
    '피트': 'ft',
    'ft': 'ft',
    'yard': 'yd',
    'yards': 'yd',
    '야드': 'yd',
    'yd': 'yd',
    'mile': 'mi',
    'miles': 'mi',
    '마일': 'mi',
    'mi': 'mi',
    // weight
    'milligram': 'mg',
    '밀리그램': 'mg',
    'mg': 'mg',
    'gram': 'g',
    'grams': 'g',
    '그램': 'g',
    'g': 'g',
    'kilogram': 'kg',
    'kilograms': 'kg',
    '킬로그램': 'kg',
    '킬로': 'kg',
    'kg': 'kg',
    'ton': 't',
    'tonne': 't',
    '톤': 't',
    't': 't',
    'ounce': 'oz',
    'ounces': 'oz',
    '온스': 'oz',
    'oz': 'oz',
    'pound': 'lb',
    'pounds': 'lb',
    '파운드': 'lb',
    'lb': 'lb',
    'lbs': 'lb',
    // volume
    'milliliter': 'ml',
    'millilitre': 'ml',
    '밀리리터': 'ml',
    'ml': 'ml',
    'liter': 'l',
    'litre': 'l',
    'liters': 'l',
    '리터': 'l',
    'l': 'l',
    'gallon': 'gal',
    'gallons': 'gal',
    '갤런': 'gal',
    'gal': 'gal',
    'quart': 'qt',
    '쿼트': 'qt',
    'qt': 'qt',
    'cup': 'cup',
    'cups': 'cup',
    '컵': 'cup',
    'fluid ounce': 'fl_oz',
    'fl oz': 'fl_oz',
    'floz': 'fl_oz',
    // temperature
    'celsius': 'c',
    '섭씨': 'c',
    '°c': 'c',
    '℃': 'c',
    'c': 'c',
    'fahrenheit': 'f',
    '화씨': 'f',
    '°f': 'f',
    '℉': 'f',
    'f': 'f',
  };

  static const modes = ['length', 'weight', 'volume', 'temperature'];

  static String modeLabel(String mode) => switch (mode) {
        'length' => '길이',
        'weight' => '무게',
        'volume' => '부피',
        'temperature' => '온도',
        _ => mode,
      };

  static List<String> unitsFor(String mode) => switch (mode) {
        'length' => lengthToMeter.keys.toList(),
        'weight' => weightToKg.keys.toList(),
        'volume' => ['ml', 'l', 'gal', 'qt', 'cup', 'fl_oz'],
        'temperature' => ['c', 'f'],
        _ => lengthToMeter.keys.toList(),
      };

  static String categoryOf(String unit) {
    final u = canonicalize(unit);
    if (lengthToMeter.containsKey(u)) return 'length';
    if (weightToKg.containsKey(u)) return 'weight';
    if (volumeToLiter.containsKey(u) || u == 'l') return 'volume';
    if (u == 'c' || u == 'f') return 'temperature';
    return 'length';
  }

  static String canonicalize(String raw) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty) return raw;
    // Prefer longer aliases.
    final aliases = unitAliases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final a in aliases) {
      if (key == a.toLowerCase()) return unitAliases[a]!;
    }
    return key;
  }

  static String labelOf(String unit) {
    final u = canonicalize(unit);
    return unitLabels[u] ?? u;
  }

  static double convertLength(double value, String from, String to) {
    final f = canonicalize(from);
    final t = canonicalize(to);
    return value * lengthToMeter[f]! / lengthToMeter[t]!;
  }

  static double convertWeight(double value, String from, String to) {
    final f = canonicalize(from);
    final t = canonicalize(to);
    return value * weightToKg[f]! / weightToKg[t]!;
  }

  static double convertVolume(double value, String from, String to) {
    final f = canonicalize(from);
    final t = canonicalize(to);
    final fromFactor = volumeToLiter[f] ?? (f == 'l' ? 1.0 : null);
    final toFactor = volumeToLiter[t] ?? (t == 'l' ? 1.0 : null);
    if (fromFactor == null || toFactor == null) {
      throw ArgumentError('Unsupported volume unit');
    }
    return value * fromFactor / toFactor;
  }

  static double convertTemperature(double value, String from, String to) {
    final f = canonicalize(from);
    final t = canonicalize(to);
    if (f == t) return value;
    if (f == 'c' && t == 'f') return value * 9 / 5 + 32;
    if (f == 'f' && t == 'c') return (value - 32) * 5 / 9;
    throw ArgumentError('Unsupported temperature unit');
  }

  static double convert({
    required double value,
    required String from,
    required String to,
  }) {
    final cat = categoryOf(from);
    if (categoryOf(to) != cat) {
      throw ArgumentError('Cannot convert across categories: $from → $to');
    }
    return switch (cat) {
      'length' => convertLength(value, from, to),
      'weight' => convertWeight(value, from, to),
      'volume' => convertVolume(value, from, to),
      'temperature' => convertTemperature(value, from, to),
      _ => throw ArgumentError('Unknown category'),
    };
  }

  static double cToF(double c) => c * 9 / 5 + 32;
  static double fToC(double f) => (f - 32) * 5 / 9;

  static String formatResult(double n) {
    if (n.abs() >= 1000 || n == n.roundToDouble()) {
      final i = n.round();
      if ((n - i).abs() < 1e-9) {
        return i.toString().replaceAllMapped(
              RegExp(r'\B(?=(\d{3})+(?!\d))'),
              (_) => ',',
            );
      }
    }
    var s = n.toStringAsFixed(6);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }

  /// Parse NL like "100 feet가 몇 m인가요?" / "5kg to lb".
  static UnitParseResult? tryParse(String utterance) {
    final text = utterance.trim();
    if (text.isEmpty) return null;

    final normalized = text
        .replaceAll('？', '?')
        .replaceAll('몇', '몇')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Temperature special: "화씨 68" / "섭씨 20도"
    final tempKo = RegExp(
      r'(화씨|섭씨)\s*(-?\d+(?:\.\d+)?)\s*도?',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (tempKo != null) {
      final from = tempKo.group(1) == '화씨' ? 'f' : 'c';
      final to = from == 'f' ? 'c' : 'f';
      final amount = double.parse(tempKo.group(2)!);
      final result = convert(value: amount, from: from, to: to);
      return UnitParseResult(
        value: amount,
        from: from,
        to: to,
        result: result,
        mode: 'temperature',
      );
    }

    final amountRe = r'(-?\d+(?:\.\d+)?)';
    // Build alias alternation (escape none needed for our aliases).
    final aliasKeys = unitAliases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final aliasAlt = aliasKeys.map(RegExp.escape).join('|');

    // Pattern A: <amount> <from> … <to>
    final reA = RegExp(
      '$amountRe\\s*($aliasAlt)\\s*(?:가|이|은|는|을|를|를|을)?\\s*'
      r'(?:몇|얼마나|얼마|to|in|into|→|->|=)?\s*'
      '(?:몇\\s*)?($aliasAlt)',
      caseSensitive: false,
    );
    final mA = reA.firstMatch(normalized);
    if (mA != null) {
      return _fromMatch(mA.group(1)!, mA.group(2)!, mA.group(3)!);
    }

    // Pattern B: <amount><from> to/in <to>
    final reB = RegExp(
      '$amountRe\\s*($aliasAlt)\\s*(?:to|in|into|→|->|=|을|를)\\s*($aliasAlt)',
      caseSensitive: false,
    );
    final mB = reB.firstMatch(normalized);
    if (mB != null) {
      return _fromMatch(mB.group(1)!, mB.group(2)!, mB.group(3)!);
    }

    // Pattern C: convert <amount> <from> to <to>
    final reC = RegExp(
      '(?:convert|변환|바꿔|환산)\\s*$amountRe\\s*($aliasAlt)\\s*'
      '(?:to|in|into|→|->|을|를|로)?\\s*($aliasAlt)',
      caseSensitive: false,
    );
    final mC = reC.firstMatch(normalized);
    if (mC != null) {
      return _fromMatch(mC.group(1)!, mC.group(2)!, mC.group(3)!);
    }

    return null;
  }

  static UnitParseResult? _fromMatch(String amt, String fromRaw, String toRaw) {
    final value = double.tryParse(amt);
    if (value == null) return null;
    final from = canonicalize(fromRaw);
    final to = canonicalize(toRaw);
    try {
      final result = convert(value: value, from: from, to: to);
      return UnitParseResult(
        value: value,
        from: from,
        to: to,
        result: result,
        mode: categoryOf(from),
      );
    } catch (_) {
      return null;
    }
  }
}

class UnitParseResult {
  const UnitParseResult({
    required this.value,
    required this.from,
    required this.to,
    required this.result,
    required this.mode,
  });

  final double value;
  final String from;
  final String to;
  final double result;
  final String mode;

  String get expression =>
      '${UnitConverter.formatResult(value)} ${UnitConverter.labelOf(from)} → ${UnitConverter.labelOf(to)}';

  String get resultText =>
      '${UnitConverter.formatResult(result)} ${UnitConverter.labelOf(to)}';
}
