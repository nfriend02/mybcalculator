/// Pure calculator engine (button + parsed expression).
class CalculatorEngine {
  String _expression = '';
  String _display = '0';
  String? _error;

  String get expression => _expression;
  String get display => _error ?? _display;
  bool get hasError => _error != null;

  void clear() {
    _expression = '';
    _display = '0';
    _error = null;
  }

  void backspace() {
    _error = null;
    if (_expression.isEmpty) {
      _display = '0';
      return;
    }
    _expression = _expression.substring(0, _expression.length - 1);
    _display = _expression.isEmpty ? '0' : _expression;
  }

  void input(String token) {
    _error = null;
    // Normalize pad glyphs (fullwidth / unicode) to ASCII operators.
    final normalized = switch (token) {
      '＝' || '=' => '=',
      '＋' || '+' => '+',
      '－' || '−' || '-' => '-',
      '×' || '*' || 'x' || 'X' => '*',
      '÷' || '/' => '/',
      _ => token,
    };
    if (normalized == '=') {
      evaluate();
      return;
    }
    if (normalized == 'C') {
      clear();
      return;
    }
    if (normalized == '⌫') {
      backspace();
      return;
    }
    _expression += normalized;
    _display = _expression;
  }

  void setExpression(String value) {
    _error = null;
    _expression = value;
    _display = value.isEmpty ? '0' : value;
  }

  double? evaluate() {
    _error = null;
    try {
      final value = evaluateExpression(_expression);
      _display = _format(value);
      _expression = _display;
      return value;
    } catch (e) {
      _error = '오류';
      return null;
    }
  }

  /// Evaluates arithmetic with + - * / and parentheses.
  static double evaluateExpression(String raw) {
    final normalized = raw
        .replaceAll('×', '*')
        .replaceAll('÷', '/')
        .replaceAll('－', '-')
        .replaceAll('−', '-')
        .replaceAll('＋', '+')
        .replaceAll(' ', '');
    if (normalized.isEmpty) return 0;
    return _Parser(normalized).parse();
  }

  static String _format(double value) {
    if (value.isNaN || value.isInfinite) throw StateError('invalid');
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }
}

class _Parser {
  _Parser(this.input);
  final String input;
  int _pos = 0;

  double parse() {
    final v = _expr();
    if (_pos < input.length) throw FormatException('Unexpected ${input[_pos]}');
    return v;
  }

  double _expr() {
    var v = _term();
    while (_pos < input.length) {
      final c = input[_pos];
      if (c == '+') {
        _pos++;
        v += _term();
      } else if (c == '-') {
        _pos++;
        v -= _term();
      } else {
        break;
      }
    }
    return v;
  }

  double _term() {
    var v = _factor();
    while (_pos < input.length) {
      final c = input[_pos];
      if (c == '*') {
        _pos++;
        v *= _factor();
      } else if (c == '/') {
        _pos++;
        final d = _factor();
        if (d == 0) throw StateError('div0');
        v /= d;
      } else {
        break;
      }
    }
    return v;
  }

  double _factor() {
    if (_match('(')) {
      final v = _expr();
      if (!_match(')')) throw FormatException('missing )');
      return v;
    }
    final start = _pos;
    if (_pos < input.length && (input[_pos] == '+' || input[_pos] == '-')) {
      _pos++;
    }
    while (_pos < input.length &&
        (input[_pos].contains(RegExp(r'[0-9.]')))) {
      _pos++;
    }
    if (start == _pos) throw FormatException('number expected');
    return double.parse(input.substring(start, _pos));
  }

  bool _match(String s) {
    if (_pos < input.length && input[_pos] == s) {
      _pos++;
      return true;
    }
    return false;
  }
}

/// Korean number / money phrase helpers for NLP calculator.
class KoreanMathParser {
  static const _digits = {
    '영': 0,
    '공': 0,
    '일': 1,
    '하나': 1,
    '이': 2,
    '둘': 2,
    '삼': 3,
    '셋': 3,
    '사': 4,
    '넷': 4,
    '오': 5,
    '다섯': 5,
    '육': 6,
    '여섯': 6,
    '칠': 7,
    '일곱': 7,
    '팔': 8,
    '여덟': 8,
    '구': 9,
    '아홉': 9,
  };

  static const _units = {
    '십': 10,
    '백': 100,
    '천': 1000,
    '만': 10000,
    '억': 100000000,
  };

  /// "삼십 나누기 삼은?" → 10
  static String? tryParse(String utterance) {
    var text = utterance.trim();
    text = text.replaceAll(RegExp(r'[?？은는이가을를]$'), '');
    text = text
        .replaceAll('더하기', '+')
        .replaceAll('플러스', '+')
        .replaceAll('빼기', '-')
        .replaceAll('마이너스', '-')
        .replaceAll('곱하기', '*')
        .replaceAll('나누기', '/')
        .replaceAll('제곱', '^2');

    // Money: "만원짜리 칼국수 세 그릇"
    final money = RegExp(r'(만|천|백)?원짜리?\s*.+?\s*([일이삼사오육칠팔구십]+)(?:\s*그릇|\s*개)?');
    final moneyMatch = money.firstMatch(text);
    if (moneyMatch != null) {
      final unitWord = moneyMatch.group(1) ?? '';
      final countWord = moneyMatch.group(2) ?? '일';
      final unit = switch (unitWord) {
        '만' => 10000,
        '천' => 1000,
        '백' => 100,
        _ => 1,
      };
      final count = _parseKoreanNumber(countWord) ?? 1;
      return (unit * count).toString();
    }

    // Replace korean numbers with digits
    final tokens = text.split(RegExp(r'\s+'));
    final buf = StringBuffer();
    for (final t in tokens) {
      final n = _parseKoreanNumber(t);
      if (n != null) {
        buf.write(n);
      } else if (RegExp(r'^[+\-*/()0-9.]+$').hasMatch(t)) {
        buf.write(t);
      } else if (t == '+' || t == '-' || t == '*' || t == '/') {
        buf.write(t);
      }
    }
    final expr = buf.toString();
    if (expr.isEmpty) return null;
    try {
      final v = CalculatorEngine.evaluateExpression(expr);
      if (v == v.roundToDouble()) return v.toInt().toString();
      return v.toStringAsFixed(4);
    } catch (_) {
      return null;
    }
  }

  static int? _parseKoreanNumber(String raw) {
    if (RegExp(r'^\d+$').hasMatch(raw)) return int.parse(raw);
    var s = raw;
    var total = 0;
    var current = 0;
    while (s.isNotEmpty) {
      var matched = false;
      for (final e in _digits.entries) {
        if (s.startsWith(e.key)) {
          current = e.value;
          s = s.substring(e.key.length);
          matched = true;
          break;
        }
      }
      if (!matched) {
        for (final e in _units.entries) {
          if (s.startsWith(e.key)) {
            if (current == 0) current = 1;
            if (e.value >= 10000) {
              total = (total + current) * e.value;
              current = 0;
            } else {
              total += current * e.value;
              current = 0;
            }
            s = s.substring(e.key.length);
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        if (total == 0 && current == 0) return null;
        break;
      }
    }
    return total + current;
  }

  static double moneyFromPhrase(String phrase) {
    final parsed = tryParse(phrase);
    return double.tryParse(parsed ?? '') ?? 0;
  }
}
