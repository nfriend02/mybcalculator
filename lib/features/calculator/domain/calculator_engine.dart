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

  /// Show formula in the expression line and the answer as the main display.
  void setResult({required String expression, required String result}) {
    _error = null;
    _expression = expression;
    _display = result.isEmpty ? '0' : result;
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
    '한': 1,
    '이': 2,
    '둘': 2,
    '두': 2,
    '삼': 3,
    '셋': 3,
    '세': 3,
    '사': 4,
    '넷': 4,
    '네': 4,
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

  /// Parse a single money amount token like "4만", "4500", "만이천" → number.
  static double? parseMoneyAmount(String raw) {
    final s = raw
        .replaceAll(',', '')
        .replaceAll('，', '')
        .replaceAll('원', '')
        .replaceAll('짜리', '')
        .replaceAll(RegExp(r'\s+'), '')
        .trim();
    if (s.isEmpty) return null;

    final eok = RegExp(r'^(\d+)억$').firstMatch(s);
    if (eok != null) return (int.parse(eok.group(1)!) * 100000000).toDouble();

    final man = RegExp(r'^(\d+)만$').firstMatch(s);
    if (man != null) return (int.parse(man.group(1)!) * 10000).toDouble();

    final cheon = RegExp(r'^(\d+)천$').firstMatch(s);
    if (cheon != null) return (int.parse(cheon.group(1)!) * 1000).toDouble();

    final plain = double.tryParse(s);
    if (plain != null) return plain;

    final korean = _parseKoreanMoneyPhrase(s);
    return korean?.toDouble();
  }

  /// "삼십 나누기 삼은?" → 10
  /// Multi-item money: "만이천원 … 3명 … 4,500원 … 세 잔" → 49500
  static String? tryParse(String utterance) {
    var text = utterance.trim();
    if (text.isEmpty) return null;

    // Foreign-currency sentences belong to FxMoneyParser — never invent KRW math.
    if (RegExp(
      r'달러|위안|엔화|USD|JPY|SGD|CNY|싱가포르|미국\s*달러|일본\s*엔|중국\s*위안',
      caseSensitive: false,
    ).hasMatch(text)) {
      return null;
    }

    final multi = _tryMultiMoney(text);
    if (multi != null) return multi;

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

  /// Sum of (unit price × quantity) phrases in one sentence.
  static String? _tryMultiMoney(String utterance) {
    final text = utterance
        .replaceAll(',', '')
        .replaceAll('，', '')
        // "만원짜리" / "원어치" → normalize to …원
        .replaceAll('짜리', '')
        .replaceAll('원어치', '원')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Order matters: "4만 원" before bare "만 원", "4500원" last among digit forms.
    final priceRe = RegExp(
      r'(?:'
      r'(\d+)\s*억\s*원' // 2억 원
      r'|'
      r'(\d+)\s*만\s*원' // 4만 원, 3만원
      r'|'
      r'(\d+)\s*천\s*원' // 5천 원
      r'|'
      r'(\d+)\s*원' // 2000원, 4500원
      r'|'
      r'(만\s*[일이삼사오육칠팔구]?천?'
      r'|천\s*[일이삼사오육칠팔구]?'
      r'|[일이삼사오육칠팔구]\s*천'
      r'|[일이삼사오육칠팔구]\s*백'
      r'|만|천|백'
      r')\s*원' // 만이천원, 만원
      r')',
    );

    final prices = <_MoneyHit>[];
    for (final m in priceRe.allMatches(text)) {
      final won = _amountFromPriceMatch(m);
      if (won != null && won > 0) {
        prices.add(_MoneyHit(index: m.start, end: m.end, amount: won));
      }
    }
    if (prices.isEmpty) return null;

    // Quantity always needs a unit (잔/개/명…).
    // Prevents "오늘"→오(5), and "2000원 … 만원"→2000×만원.
    final qtyRe = RegExp(
      r'(?:하나|둘|셋|넷|다섯|여섯|일곱|여덟|아홉|한|두|세|네|'
      r'일|이|삼|사|오|육|칠|팔|구|십|\d+)'
      r'\s*(?:명|그릇|잔|개|인분|접시|병|판|장|번)',
    );

    var total = 0;
    var usedAnyQty = false;
    for (var i = 0; i < prices.length; i++) {
      final price = prices[i];
      final prevEnd = i > 0 ? prices[i - 1].end : 0;
      final nextStart =
          i + 1 < prices.length ? prices[i + 1].index : text.length;

      // Search only in the gap before/after this price, not into other prices.
      final after = text.substring(
        price.end,
        nextStart.clamp(price.end, text.length),
      );
      final beforeStart = prevEnd.clamp(0, price.index);
      final before = text.substring(beforeStart, price.index);

      var qty = 1;
      final afterMatch = qtyRe.firstMatch(after);
      final beforeMatch = qtyRe.allMatches(before).toList().lastOrNull;

      if (afterMatch != null) {
        qty = _qtyFromMatch(afterMatch);
        usedAnyQty = true;
      } else if (beforeMatch != null) {
        qty = _qtyFromMatch(beforeMatch);
        usedAnyQty = true;
      }
      total += price.amount * qty;
    }

    // Accept multi-price sums (qty defaults to 1) or any priced×qty hit.
    if (!usedAnyQty && prices.length < 2) return null;
    return total.toString();
  }

  static int? _amountFromPriceMatch(RegExpMatch m) {
    final eok = m.group(1);
    final man = m.group(2);
    final cheon = m.group(3);
    final plain = m.group(4);
    final korean = m.group(5);

    if (eok != null) {
      final n = int.tryParse(eok);
      return n == null ? null : n * 100000000;
    }
    if (man != null) {
      final n = int.tryParse(man);
      return n == null ? null : n * 10000;
    }
    if (cheon != null) {
      final n = int.tryParse(cheon);
      return n == null ? null : n * 1000;
    }
    if (plain != null) {
      return int.tryParse(plain);
    }
    if (korean != null) {
      return _parseKoreanMoneyPhrase(korean.replaceAll(RegExp(r'\s+'), ''));
    }
    return null;
  }

  static int _qtyFromMatch(RegExpMatch m) {
    final raw = m.group(0)!;
    final numPart = raw
        .replaceAll(RegExp(r'(명|그릇|잔|개|인분|접시|병|판|장|번)\s*$'), '')
        .trim();
    if (RegExp(r'^\d+$').hasMatch(numPart)) {
      return int.tryParse(numPart) ?? 1;
    }
    return _parseKoreanNumber(numPart) ?? 1;
  }

  static int? _parseKoreanMoneyPhrase(String phrase) {
    // "만이천" → 12000, "만오천" → 15000, "만" → 10000
    var s = phrase.replaceAll('원', '').replaceAll('짜리', '').trim();
    if (s.isEmpty) return null;
    if (RegExp(r'^\d+$').hasMatch(s)) return int.parse(s);

    var total = 0;
    if (s.startsWith('만')) {
      total += 10000;
      s = s.substring(1);
    }
    if (s.startsWith('억')) {
      total += 100000000;
      s = s.substring(1);
    }

    // Remaining like "이천", "오천", "삼백"
    final rest = _parseKoreanNumber(s);
    if (rest != null) total += rest;
    return total > 0 ? total : null;
  }

  static int? _parseKoreanNumber(String raw) {
    if (RegExp(r'^\d+$').hasMatch(raw)) return int.parse(raw);
    var s = raw;
    var total = 0;
    var current = 0;
    var consumed = false;
    while (s.isNotEmpty) {
      var matched = false;
      // Longer digit words first (already insertion-ordered in map).
      for (final e in _digits.entries) {
        if (s.startsWith(e.key)) {
          current = e.value;
          s = s.substring(e.key.length);
          matched = true;
          consumed = true;
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
            consumed = true;
            break;
          }
        }
      }
      if (!matched) {
        // Allow a single trailing particle after a valid number (삼은, 십을…).
        if (consumed &&
            RegExp(r'^[은는이가을를만]$').hasMatch(s) &&
            s.length == 1) {
          s = '';
          break;
        }
        // Reject partial matches like "오늘"→오, "구매하고"→구.
        return null;
      }
    }
    if (!consumed) return null;
    return total + current;
  }

  static double moneyFromPhrase(String phrase) {
    final parsed = tryParse(phrase);
    return double.tryParse(parsed ?? '') ?? 0;
  }
}

class _MoneyHit {
  const _MoneyHit({
    required this.index,
    required this.end,
    required this.amount,
  });

  final int index;
  final int end;
  final int amount;
}
