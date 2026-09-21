import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../entities/weather/weather_snapshot.dart';
import '../../../shared/config/app_config.dart';

class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<WeatherSnapshot> fetch(String city) async {
    final key = AppConfig.openWeatherApiKey;
    if (key == null || key.startsWith('your_')) {
      return WeatherSnapshot(
        city: city,
        temperatureC: 22.5,
        description: '맑음 (데모)',
        humidity: 55,
      );
    }

    // Guidelines: API endpoints use /api prefix (proxied on Netlify).
    final uri = Uri.parse(
      '${AppConfig.apiPrefix}/weather',
    ).replace(queryParameters: {'q': city, 'units': 'metric', 'lang': 'kr'});

    try {
      final res = await _client.get(uri);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return WeatherSnapshot(
          city: data['name'] as String? ?? city,
          temperatureC: (data['main']?['temp'] as num?)?.toDouble() ?? 0,
          description:
              (data['weather'] as List?)?.firstOrNull?['description'] as String? ??
                  '',
          humidity: (data['main']?['humidity'] as num?)?.toInt(),
        );
      }
    } catch (_) {
      // fall through to demo
    }

    return WeatherSnapshot(
      city: city,
      temperatureC: 18,
      description: '정보를 불러오지 못해 데모 값을 표시합니다',
      humidity: 60,
    );
  }
}
