import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../entities/weather/weather_snapshot.dart';
import '../../../shared/config/app_config.dart';

/// Korean / common display names → OpenWeather `q` values.
const cityAliases = <String, String>{
  // Korea
  '서울': 'Seoul',
  '부산': 'Busan',
  '인천': 'Incheon',
  '대구': 'Daegu',
  '대전': 'Daejeon',
  '광주': 'Gwangju',
  '울산': 'Ulsan',
  '제주': 'Jeju',
  // Japan
  '도쿄': 'Tokyo',
  '오사카': 'Osaka',
  '교토': 'Kyoto',
  '나고야': 'Nagoya',
  '요코하마': 'Yokohama',
  '요꼬하마': 'Yokohama',
  '후쿠오카': 'Fukuoka',
  '삿포로': 'Sapporo',
  // China / TW / HK
  '베이징': 'Beijing',
  '북경': 'Beijing',
  '상하이': 'Shanghai',
  '상해': 'Shanghai',
  '광저우': 'Guangzhou',
  '선전': 'Shenzhen',
  '홍콩': 'Hong Kong',
  '타이베이': 'Taipei',
  '대만': 'Taipei',
  // SE Asia
  '싱가포르': 'Singapore',
  '방콕': 'Bangkok',
  '호치민': 'Ho Chi Minh City',
  '하노이': 'Hanoi',
  '자카르타': 'Jakarta',
  '쿠알라룸푸르': 'Kuala Lumpur',
  '마닐라': 'Manila',
  // Americas
  '뉴욕': 'New York',
  '로스앤젤레스': 'Los Angeles',
  '엘에이': 'Los Angeles',
  '샌프란시스코': 'San Francisco',
  '시카고': 'Chicago',
  '시애틀': 'Seattle',
  '토론토': 'Toronto',
  '밴쿠버': 'Vancouver',
  '멕시코시티': 'Mexico City',
  // Europe
  '런던': 'London',
  '파리': 'Paris',
  '베를린': 'Berlin',
  '로마': 'Rome',
  '마드리드': 'Madrid',
  '바르셀로나': 'Barcelona',
  '암스테르담': 'Amsterdam',
  '취리히': 'Zurich',
  '모스크바': 'Moscow',
  // Oceania / Mid-East / Africa
  '시드니': 'Sydney',
  '멜버른': 'Melbourne',
  '오클랜드': 'Auckland',
  '두바이': 'Dubai',
  '아부다비': 'Abu Dhabi',
  '카이로': 'Cairo',
  '케이프타운': 'Cape Town',
  // India
  '뭄바이': 'Mumbai',
  '델리': 'New Delhi',
  '뉴델리': 'New Delhi',
  '방갈로르': 'Bengaluru',
  // Vienna — avoid bare '빈' (matches 빈칸/비닐…)
  '비엔나': 'Vienna',
  '빈시': 'Vienna',
};

/// Quick-pick cities for the lookup panel.
const popularWeatherCities = <String>[
  '서울',
  '부산',
  '도쿄',
  '요코하마',
  '오사카',
  '싱가포르',
  '방콕',
  '베이징',
  '상하이',
  '홍콩',
  '타이베이',
  '뉴욕',
  '로스앤젤레스',
  '샌프란시스코',
  '런던',
  '파리',
  '베를린',
  '시드니',
  '멜버른',
  '두바이',
];

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherSnapshot> fetch(String city) async {
    final queryCity = resolveCity(city);

    final uri = Uri.base.replace(
      path: '${AppConfig.apiPrefix}/weather',
      queryParameters: {
        'q': queryCity,
        'units': 'metric',
        'lang': 'kr',
      },
    );

    try {
      final res = await _client.get(uri);
      final data = jsonDecode(res.body);
      if (data is! Map<String, dynamic>) {
        throw const FormatException('Unexpected weather payload');
      }

      if (res.statusCode != 200 || data['error'] == true) {
        final message = data['message']?.toString() ??
            '날씨 정보를 불러오지 못했습니다 (${res.statusCode})';
        return WeatherSnapshot(
          city: city,
          temperatureC: 0,
          description: message,
          humidity: null,
          ok: false,
        );
      }

      return WeatherSnapshot(
        city: data['name'] as String? ?? city,
        temperatureC: (data['main']?['temp'] as num?)?.toDouble() ?? 0,
        description:
            (data['weather'] as List?)?.firstOrNull?['description'] as String? ??
                '',
        humidity: (data['main']?['humidity'] as num?)?.toInt(),
        ok: true,
      );
    } catch (e) {
      return WeatherSnapshot(
        city: city,
        temperatureC: 0,
        description: '날씨 API 연결 실패: $e',
        humidity: null,
        ok: false,
      );
    }
  }

  /// Fetch several cities and return snapshots in request order.
  Future<List<WeatherSnapshot>> fetchMany(List<String> cities) async {
    final unique = <String>[];
    for (final c in cities) {
      final t = c.trim();
      if (t.isEmpty) continue;
      if (!unique.any((u) => u.toLowerCase() == t.toLowerCase())) {
        unique.add(t);
      }
    }
    if (unique.isEmpty) return [];
    return Future.wait(unique.map(fetch));
  }

  /// Resolve Korean aliases; otherwise pass through for OpenWeather.
  static String resolveCity(String city) {
    final raw = city.trim();
    if (raw.isEmpty) return 'Seoul';
    final compact = raw.replaceAll(RegExp(r'\s+'), '');
    return cityAliases[raw] ??
        cityAliases[compact] ??
        cityAliases[raw.toLowerCase()] ??
        raw;
  }

  /// Pull known city names from a natural-language weather question.
  static List<String> extractCities(String utterance) {
    final text = utterance.trim();
    if (text.isEmpty) return [];

    final found = <({int index, String name})>[];

    // Longer Korean aliases first to avoid partial overlaps.
    final keys = cityAliases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final key in keys) {
      var start = 0;
      while (true) {
        final i = text.indexOf(key, start);
        if (i < 0) break;
        if (!_overlaps(found, i, i + key.length)) {
          found.add((index: i, name: key));
        }
        start = i + key.length;
      }
    }

    // Latin city tokens (Singapore, Yokohama, New York, …)
    final latin = RegExp(
      r'\b(?:New York|Los Angeles|San Francisco|Hong Kong|'
      r'Ho Chi Minh(?: City)?|Kuala Lumpur|Cape Town|Abu Dhabi|'
      r'New Delhi|Mexico City|'
      r'[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b',
    );
    for (final m in latin.allMatches(text)) {
      final name = m.group(0)!;
      if (_isNoiseLatin(name)) continue;
      if (!_overlaps(found, m.start, m.end)) {
        found.add((index: m.start, name: name));
      }
    }

    found.sort((a, b) => a.index.compareTo(b.index));
    return found.map((e) => e.name).toList();
  }

  static bool _overlaps(List<({int index, String name})> hits, int s, int e) {
    for (final h in hits) {
      final he = h.index + h.name.length;
      if (s < he && e > h.index) return true;
    }
    return false;
  }

  static bool _isNoiseLatin(String name) {
    const noise = {
      'Today',
      'Tomorrow',
      'Weather',
      'Please',
      'What',
      'How',
      'The',
      'And',
      'For',
      'With',
    };
    return noise.contains(name);
  }

  void dispose() => _client.close();
}
