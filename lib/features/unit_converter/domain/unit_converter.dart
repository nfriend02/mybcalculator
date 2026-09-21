class UnitConverter {
  static const lengthToMeter = <String, double>{
    'mm': 0.001,
    'cm': 0.01,
    'm': 1,
    'km': 1000,
    'in': 0.0254,
    'ft': 0.3048,
  };

  static const weightToKg = <String, double>{
    'mg': 0.000001,
    'g': 0.001,
    'kg': 1,
    't': 1000,
    'lb': 0.453592,
  };

  static double convertLength(double value, String from, String to) {
    return value * lengthToMeter[from]! / lengthToMeter[to]!;
  }

  static double convertWeight(double value, String from, String to) {
    return value * weightToKg[from]! / weightToKg[to]!;
  }

  static double cToF(double c) => c * 9 / 5 + 32;
  static double fToC(double f) => (f - 32) * 5 / 9;
}
