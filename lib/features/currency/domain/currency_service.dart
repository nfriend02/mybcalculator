import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/config/app_config.dart';

/// Snapshot of FX rates used for KRW conversion.
class FxRateSnapshot {
  const FxRateSnapshot({
    required this.rates,
    required this.source,
    required this.label,
    this.asOf,
  });

  /// KRW per 1 unit of each code.
  final Map<String, double> rates;

  /// live | previous_close | demo | cache
  final String source;

  /// 오늘 환율 | 직전 종가 | 참고 환율
  final String label;

  final String? asOf;

  bool get isLive => source == 'live';
  bool get isPreviousClose =>
      source == 'previous_close' || source == 'cache';
}

/// Exchange rates — current first, then previous close, then demo.
class CurrencyService {
  CurrencyService({
    http.Client? client,
    FxRateSnapshot? fixedSnapshot,
  })  : _client = client ?? http.Client(),
        _fixedSnapshot = fixedSnapshot;

  final http.Client _client;
  final FxRateSnapshot? _fixedSnapshot;
  FxRateSnapshot? _cache;
  DateTime? _cacheAt;

  static const _prefsKey = 'fx_last_good_rates_v1';

  /// Historical fixed: 1 EUR = 6.55957 FRF (French franc, pre-euro).
  static const frfPerEur = 6.55957;

  /// Codes shown in the FX UI (KRW + foreign).
  static const supportedCodes = <String>[
    'KRW',
    'USD',
    'JPY',
    'SGD',
    'EUR',
    'CNY',
    'GBP',
    'FRF',
    'TWD',
    'CAD',
    'AUD',
  ];

  /// Foreign-only codes (no KRW).
  static List<String> get foreignCodes =>
      supportedCodes.where((c) => c != 'KRW').toList();

  /// Demo mid-market-ish rates to KRW (offline last resort).
  static const demoToKrw = <String, double>{
    'USD': 1350,
    'EUR': 1460,
    'JPY': 9.1,
    'CNY': 185,
    'GBP': 1710,
    'SGD': 1020,
    'TWD': 42,
    'CAD': 980,
    'AUD': 880,
    // FRF derived from EUR demo ≈ 1460 / 6.55957
    'FRF': 222.57,
    'KRW': 1,
  };

  /// Short unit label (e.g. for footnotes).
  static const unitLabelKo = <String, String>{
    'KRW': '원',
    'USD': '달러',
    'JPY': '엔',
    'SGD': '싱가포르 달러',
    'CNY': '위안',
    'EUR': '유로',
    'GBP': '파운드',
    'FRF': '프랑',
    'TWD': '대만 달러',
    'CAD': '캐나다 달러',
    'AUD': '호주 달러',
  };

  /// Dropdown display name.
  static const codeLabelKo = <String, String>{
    'KRW': '원화 (KRW)',
    'USD': '미국 달러 (USD)',
    'JPY': '일본 엔 (JPY)',
    'SGD': '싱가포르 달러 (SGD)',
    'EUR': '유럽 유로 (EUR)',
    'CNY': '중국 위안 (CNY)',
    'GBP': '영국 파운드 (GBP)',
    'FRF': '프랑스 프랑 (FRF)',
    'TWD': '대만 달러 (TWD)',
    'CAD': '캐나다 달러 (CAD)',
    'AUD': '호주 달러 (AUD)',
  };

  static String labelOf(String code) =>
      codeLabelKo[code.toUpperCase()] ?? code.toUpperCase();

  static String unitOf(String code) =>
      unitLabelKo[code.toUpperCase()] ?? code.toUpperCase();

  Future<double> convert({
    required double amount,
    required String from,
    String to = 'KRW',
  }) async {
    final snap = await snapshot();
    final fromRate = snap.rates[from.toUpperCase()];
    final toRate = snap.rates[to.toUpperCase()];
    if (fromRate == null || toRate == null) {
      throw ArgumentError('Unsupported currency: $from → $to');
    }
    return amount * fromRate / toRate;
  }

  Future<double?> rateToKrw(String code) async {
    final snap = await snapshot();
    return snap.rates[code.toUpperCase()];
  }

  Future<Map<String, double>> ratesToKrw({bool forceRefresh = false}) async {
    final snap = await snapshot(forceRefresh: forceRefresh);
    return snap.rates;
  }

  Future<FxRateSnapshot> snapshot({bool forceRefresh = false}) async {
    final fixed = _fixedSnapshot;
    if (fixed != null) return fixed;

    final cached = _cache;
    final at = _cacheAt;
    if (!forceRefresh &&
        cached != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(minutes: 15)) {
      return cached;
    }

    final fresh = await _fetchSnapshot();
    _cache = fresh;
    _cacheAt = DateTime.now();
    if (fresh.source == 'live' || fresh.source == 'previous_close') {
      await _persistLastGood(fresh);
    }
    return fresh;
  }

  /// e.g. "1달러의 오늘 환율인 1,350원을 적용했습니다"
  static String rateAppliedMessage(
    String code,
    double rate, {
    String label = '오늘 환율',
  }) {
    final unit = unitLabelKo[code.toUpperCase()] ?? code.toUpperCase();
    final pretty = _formatKrw(rate);
    return '1${unit}의 $label인 $pretty원을 적용했습니다';
  }

  static String _formatKrw(double rate) {
    if (rate >= 100) {
      final n = rate.round();
      return n.toString().replaceAllMapped(
            RegExp(r'\B(?=(\d{3})+(?!\d))'),
            (_) => ',',
          );
    }
    if (rate == rate.roundToDouble()) return rate.toInt().toString();
    return rate.toStringAsFixed(2);
  }

  Future<FxRateSnapshot> _fetchSnapshot() async {
    final fromApi = await _fromAppApi();
    if (fromApi != null && fromApi.source != 'demo') return fromApi;

    final live = await _fromOpenErApi();
    if (live != null) return live;

    final stored = await _loadLastGood();
    if (stored != null) return stored;

    if (fromApi != null) return fromApi;

    return const FxRateSnapshot(
      rates: demoToKrw,
      source: 'demo',
      label: '참고 환율',
    );
  }

  Future<FxRateSnapshot?> _fromAppApi() async {
    try {
      final uri = Uri.base.replace(path: '${AppConfig.apiPrefix}/exchange');
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return null;
      return _parsePayload(data);
    } catch (e) {
      debugPrint('FX /api/exchange failed: $e');
      return null;
    }
  }

  Future<FxRateSnapshot?> _fromOpenErApi() async {
    try {
      final uri = Uri.parse('https://open.er-api.com/v6/latest/USD');
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) return null;
      if (data['result'] != null && data['result'] != 'success') return null;
      final raw = data['rates'];
      if (raw is! Map) return null;
      final table = <String, double>{};
      raw.forEach((k, v) {
        if (v is num) table[k.toString().toUpperCase()] = v.toDouble();
      });
      final rates = _ratesFromUsdTable(table);
      if (rates == null) return null;
      return FxRateSnapshot(
        rates: rates,
        source: 'live',
        label: '오늘 환율',
        asOf: data['time_last_update_utc']?.toString(),
      );
    } catch (e) {
      debugPrint('FX open.er-api failed: $e');
      return null;
    }
  }

  FxRateSnapshot? _parsePayload(Map<String, dynamic> data) {
    final raw = data['rates'];
    if (raw is! Map) return null;
    final parsed = <String, double>{};
    raw.forEach((k, v) {
      if (v is num) parsed[k.toString().toUpperCase()] = v.toDouble();
    });
    if (parsed.isEmpty) return null;
    for (final e in demoToKrw.entries) {
      parsed.putIfAbsent(e.key, () => e.value);
    }
    _ensureFrf(parsed);
    final source = (data['source'] ?? 'live').toString();
    final label = (data['label'] ?? _labelForSource(source)).toString();
    return FxRateSnapshot(
      rates: parsed,
      source: source,
      label: label,
      asOf: data['asOf']?.toString(),
    );
  }

  static String _labelForSource(String source) {
    return switch (source) {
      'live' => '오늘 환율',
      'previous_close' || 'cache' => '직전 종가',
      _ => '참고 환율',
    };
  }

  /// conversion table: 1 USD = X CODE → KRW per 1 CODE
  static Map<String, double>? _ratesFromUsdTable(Map<String, double> cr) {
    final usdToKrw = cr['KRW'];
    if (usdToKrw == null || usdToKrw <= 0) return null;
    final rates = <String, double>{'KRW': 1, 'USD': usdToKrw};
    for (final code in demoToKrw.keys) {
      if (code == 'KRW' || code == 'USD' || code == 'FRF') continue;
      final usdToCode = cr[code];
      if (usdToCode == null || usdToCode <= 0) {
        rates[code] = demoToKrw[code]!;
      } else {
        rates[code] = usdToKrw / usdToCode;
      }
    }
    _ensureFrf(rates);
    return rates;
  }

  static void _ensureFrf(Map<String, double> rates) {
    if (rates.containsKey('FRF') && (rates['FRF'] ?? 0) > 0) return;
    final eur = rates['EUR'] ?? demoToKrw['EUR']!;
    rates['FRF'] = eur / frfPerEur;
  }

  Future<void> _persistLastGood(FxRateSnapshot snap) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({
          'rates': snap.rates,
          'asOf': snap.asOf,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      debugPrint('FX persist failed: $e');
    }
  }

  Future<FxRateSnapshot?> _loadLastGood() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final ratesRaw = data['rates'];
      if (ratesRaw is! Map) return null;
      final rates = <String, double>{};
      ratesRaw.forEach((k, v) {
        if (v is num) rates[k.toString().toUpperCase()] = v.toDouble();
      });
      if (rates.isEmpty) return null;
      for (final e in demoToKrw.entries) {
        rates.putIfAbsent(e.key, () => e.value);
      }
      _ensureFrf(rates);
      return FxRateSnapshot(
        rates: rates,
        source: 'previous_close',
        label: '직전 종가',
        asOf: data['asOf']?.toString() ?? data['savedAt']?.toString(),
      );
    } catch (e) {
      debugPrint('FX load cache failed: $e');
      return null;
    }
  }

  void dispose() => _client.close();
}
