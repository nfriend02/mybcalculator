import '../../currency/domain/currency_service.dart';
import 'calculator_engine.dart';

/// Result of FX-aware natural-language money calc (always in KRW).
class FxCalcResult {
  const FxCalcResult({
    required this.krwTotal,
    required this.rateNotes,
    required this.usedCodes,
    this.breakdown = const [],
  });

  final String krwTotal;
  final List<String> rateNotes;
  final Set<String> usedCodes;
  final List<String> breakdown;

  String get rateNoteText => rateNotes.join('\n');
}

/// Parses amounts in major FX (and KRW) then sums in won.
class FxMoneyParser {
  /// Longest-first currency unit patterns → ISO code.
  static final _currencyUnits = <({RegExp pattern, String code})>[
    (pattern: RegExp(r'싱가포르\s*달러|싱가폴\s*달러|SGD|sgd'), code: 'SGD'),
    (pattern: RegExp(r'캐나다\s*달러|CAD|cad'), code: 'CAD'),
    (pattern: RegExp(r'호주\s*달러|AUD|aud'), code: 'AUD'),
    (pattern: RegExp(r'대만\s*달러|TWD|twd|신\s*대만'), code: 'TWD'),
    (pattern: RegExp(r'미국\s*달러|USD|usd|미\s*달러'), code: 'USD'),
    (pattern: RegExp(r'일본\s*엔|엔화|JPY|jpy'), code: 'JPY'),
    (pattern: RegExp(r'중국\s*위안|위안화|인민폐|CNY|cny'), code: 'CNY'),
    (pattern: RegExp(r'유럽\s*유로|유로화|EUR|eur'), code: 'EUR'),
    (pattern: RegExp(r'영국\s*파운드|파운드화|GBP|gbp'), code: 'GBP'),
    (pattern: RegExp(r'프랑스\s*프랑|프랑화|FRF|frf'), code: 'FRF'),
    // Bare forms after specific ones
    (pattern: RegExp(r'유로'), code: 'EUR'),
    (pattern: RegExp(r'파운드'), code: 'GBP'),
    (pattern: RegExp(r'프랑'), code: 'FRF'),
    (pattern: RegExp(r'달러|불'), code: 'USD'),
    (pattern: RegExp(r'엔'), code: 'JPY'),
    (pattern: RegExp(r'위안'), code: 'CNY'),
    (pattern: RegExp(r'원어치|원'), code: 'KRW'),
  ];

  static bool mentionsForeignCurrency(String text) {
    return RegExp(
      r'싱가포르\s*달러|싱가폴\s*달러|캐나다\s*달러|호주\s*달러|대만\s*달러|'
      r'미국\s*달러|일본\s*엔|중국\s*위안|유럽\s*유로|영국\s*파운드|프랑스\s*프랑|'
      r'달러|위안화|위안|인민폐|엔화|유로|파운드|프랑|'
      r'USD|JPY|SGD|CNY|EUR|GBP|FRF|TWD|CAD|AUD|불|'
      r'\d\s*엔|\d만\s*엔|만\s*엔',
      caseSensitive: false,
    ).hasMatch(text);
  }

  static Future<FxCalcResult?> tryParse(
    String utterance, {
    required CurrencyService currency,
  }) async {
    final normalized = utterance
        .replaceAll(',', '')
        .replaceAll('，', '')
        .replaceAll('짜리', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    final hits = _findAmountHits(normalized);
    if (hits.isEmpty) return null;

    final hasFx = hits.any((h) => h.code != 'KRW');
    if (!hasFx) {
      return null;
    }

    final snap = await currency.snapshot();
    final rates = snap.rates;
    final used = <String>{};
    final breakdown = <String>[];
    var total = 0.0;

    for (final hit in hits) {
      final rate = rates[hit.code];
      if (rate == null) {
        // Missing rate → let Gemini + rewriteToKrwPrompt handle the utterance.
        return null;
      }
      final krw = hit.amount * rate;
      total += krw;
      if (hit.code != 'KRW') used.add(hit.code);
      final unit = CurrencyService.unitLabelKo[hit.code] ?? hit.code;
      breakdown.add(
        hit.code == 'KRW'
            ? '${_fmt(hit.amount)}원'
            : '${_fmt(hit.amount)}$unit → ${_fmt(krw)}원',
      );
    }

    if (total <= 0) return null;

    final notes = used
        .map((code) {
          final rate = rates[code]!;
          return CurrencyService.rateAppliedMessage(
            code,
            rate,
            label: snap.label,
          );
        })
        .toList();

    final rounded = total.roundToDouble() == total
        ? total.toInt().toString()
        : total.toStringAsFixed(0);

    return FxCalcResult(
      krwTotal: rounded,
      rateNotes: notes,
      usedCodes: used,
      breakdown: breakdown,
    );
  }

  /// Rewrite utterance replacing FX amounts with KRW so Gemini can compute.
  static Future<String> rewriteToKrwPrompt(
    String utterance, {
    required CurrencyService currency,
  }) async {
    if (!mentionsForeignCurrency(utterance)) return utterance;

    final snap = await currency.snapshot();
    final buf = StringBuffer()
      ..writeln(utterance.trim())
      ..writeln()
      ..writeln('【${snap.label} — 반드시 아래 환율로 원화(KRW) 환산 후 계산】');
    for (final code in CurrencyService.foreignCodes) {
      final rate = snap.rates[code];
      if (rate == null) continue;
      buf.writeln(
        CurrencyService.rateAppliedMessage(code, rate, label: snap.label),
      );
    }
    buf.writeln('최종 result는 원화 숫자만. explanation에 적용한 환율 문구를 포함하세요.');
    return buf.toString();
  }

  static List<_FxHit> _findAmountHits(String text) {
    final hits = <_FxHit>[];

    final amountToken =
        r'(?:'
        r'\d+\s*억'
        r'|'
        r'\d+\s*만'
        r'|'
        r'\d+\s*천'
        r'|'
        r'\d+(?:\.\d+)?'
        r'|'
        r'만\s*[일이삼사오육칠팔구]?천?'
        r'|'
        r'천\s*[일이삼사오육칠팔구]?'
        r'|'
        r'[일이삼사오육칠팔구]\s*천'
        r'|'
        r'[일이삼사오육칠팔구]\s*백'
        r'|'
        r'만|천|백'
        r')';

    for (final unit in _currencyUnits) {
      final re = RegExp(
        '($amountToken)\\s*(?:${unit.pattern.pattern})',
        caseSensitive: false,
      );
      for (final m in re.allMatches(text)) {
        if (_overlaps(hits, m.start, m.end)) continue;
        final rawAmt = m.group(1)!.replaceAll(RegExp(r'\s+'), '');
        final amount = _parseAmountToken(rawAmt);
        if (amount == null || amount <= 0) continue;
        hits.add(
          _FxHit(
            index: m.start,
            end: m.end,
            amount: amount,
            code: unit.code,
          ),
        );
      }
    }

    hits.sort((a, b) => a.index.compareTo(b.index));
    return hits;
  }

  static bool _overlaps(List<_FxHit> hits, int start, int end) {
    for (final h in hits) {
      if (start < h.end && end > h.index) return true;
    }
    return false;
  }

  static double? _parseAmountToken(String raw) {
    return KoreanMathParser.parseMoneyAmount(raw);
  }

  static String _fmt(double n) {
    if (n == n.roundToDouble()) {
      final i = n.toInt();
      return i.toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => ',',
          );
    }
    return n.toStringAsFixed(2);
  }
}

class _FxHit {
  const _FxHit({
    required this.index,
    required this.end,
    required this.amount,
    required this.code,
  });

  final int index;
  final int end;
  final double amount;
  final String code;
}
