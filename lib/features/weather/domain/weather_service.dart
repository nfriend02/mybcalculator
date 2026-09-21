import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../entities/weather/weather_snapshot.dart';
import '../../../shared/config/app_config.dart';

/// Korean / common display names → OpenWeather `q` values.
const _cityAliases = <String, String>{
  '요코하마': 'Yokohama',
  '요꼬하마': 'Yokohama',
  '서울': 'Seoul',
  '부산': 'Busan',
  '인천': 'Incheon',
  '대구': 'Daegu',
  '대전': 'Daejeon',
  '광주': 'Gwangju',
  '도쿄': 'Tokyo',
  '오사카': 'Osaka',
  '교토': 'Kyoto',
  '나고야': 'Nagoya',
  '베이징': 'Beijing',
  '상하이': 'Shanghai',
  '뉴욕': 'New York',
  '런던': 'London',
  '파리': 'Paris',
};

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherSnapshot> fetch(String city) async {
    final queryCity = _resolveCity(city);

    // Always hit `/api/weather` — the OpenWeather key lives in Netlify env.
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
        );
      }

      return WeatherSnapshot(
        city: data['name'] as String? ?? city,
        temperatureC: (data['main']?['temp'] as num?)?.toDouble() ?? 0,
        description:
            (data['weather'] as List?)?.firstOrNull?['description'] as String? ??
                '',
        humidity: (data['main']?['humidity'] as num?)?.toInt(),
      );
    } catch (e) {
      return WeatherSnapshot(
        city: city,
        temperatureC: 0,
        description: '날씨 API 연결 실패: $e',
        humidity: null,
      );
    }
  }

  String _resolveCity(String city) {
    final raw = city.trim();
    if (raw.isEmpty) return 'Seoul';
    return _cityAliases[raw] ?? _cityAliases[raw.replaceAll(' ', '')] ?? raw;
  }
}
