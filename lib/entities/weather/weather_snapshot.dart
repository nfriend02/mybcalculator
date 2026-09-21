class WeatherSnapshot {
  const WeatherSnapshot({
    required this.city,
    required this.temperatureC,
    required this.description,
    this.humidity,
  });

  final String city;
  final double temperatureC;
  final String description;
  final int? humidity;
}
