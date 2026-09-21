class WeatherSnapshot {
  const WeatherSnapshot({
    required this.city,
    required this.temperatureC,
    required this.description,
    this.humidity,
    this.ok = true,
  });

  final String city;
  final double temperatureC;
  final String description;
  final int? humidity;
  final bool ok;

  String get summaryLine {
    if (!ok) return '$city — $description';
    final hum = humidity != null ? ' · 습도 $humidity%' : '';
    return '$city ${temperatureC.toStringAsFixed(1)}°C · $description$hum';
  }
}
