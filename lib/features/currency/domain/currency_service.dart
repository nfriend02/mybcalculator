import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../shared/config/app_config.dart';

/// Exchange rates — prefers live `/api/exchange`, falls back to demo rates.
class CurrencyService {
  CurrencyService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Demo mid-market-ish rates to KRW (offline / missing key).
  static const demoToKrw = <String, double>{
    'USD': 1350,
    'EUR': 1460,
    'JPY': 9.1,
    'CNY': 185,
    'GBP': 1710,
    'KRW': 1,
  };

  Future<double> convert({
    required double amount,
    required String from,
    String to = 'KRW',
  }) async {
    final rates = await _rates();
    final fromRate = rates[from.toUpperCase()];
    final toRate = rates[to.toUpperCase()];
    if (fromRate == null || toRate == null) {
      throw ArgumentError('Unsupported currency');
    }
    final inKrw = amount * fromRate;
    return inKrw / toRate;
  }

  Future<Map<String, double>> _rates() async {
    final key = AppConfig.exchangeRateApiKey;
    final shouldTryLive =
        key != null && key.isNotEmpty && !key.startsWith('your_');

    if (shouldTryLive) {
      try {
        final uri = Uri.parse('${AppConfig.apiPrefix}/exchange');
        final res = await _client.get(uri);
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final raw = data['rates'];
          if (raw is Map) {
            final parsed = <String, double>{};
            raw.forEach((k, v) {
              if (v is num) parsed[k.toString().toUpperCase()] = v.toDouble();
            });
            if (parsed.isNotEmpty) return parsed;
          }
        }
      } catch (_) {
        // fall through to demo
      }
    }

    return demoToKrw;
  }
}
