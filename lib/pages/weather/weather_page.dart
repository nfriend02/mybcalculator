import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../entities/weather/weather_snapshot.dart';
import '../../features/weather/domain/weather_service.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final _city = TextEditingController(text: '요코하마');
  final _service = WeatherService();
  WeatherSnapshot? _snap;
  bool _loading = false;

  Future<void> _fetch() async {
    setState(() => _loading = true);
    try {
      final snap = await _service.fetch(_city.text.trim());
      setState(() => _snap = snap);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _city.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('날씨 조회', style: GoogleFonts.fredoka(fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          '예: "지금 요코하마 날씨는?"',
          style: GoogleFonts.nunito(
            color: AppTheme.ink.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _city,
          decoration: InputDecoration(
            labelText: '도시',
            filled: true,
            fillColor: AppTheme.sky.withValues(alpha: 0.45),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _fetch,
          child: Text(_loading ? '조회 중…' : '날씨 보기'),
        ),
        if (_snap != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.sky.withValues(alpha: 0.9),
                  AppTheme.lavender.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text('🌤️', style: const TextStyle(fontSize: 48)),
                Text(
                  _snap!.city,
                  style: GoogleFonts.fredoka(fontSize: 26),
                ),
                Text(
                  '${_snap!.temperatureC.toStringAsFixed(1)}°C',
                  style: GoogleFonts.fredoka(fontSize: 40),
                ),
                Text(
                  _snap!.description,
                  style: GoogleFonts.nunito(fontSize: 16),
                ),
                if (_snap!.humidity != null)
                  Text('습도 ${_snap!.humidity}%',
                      style: GoogleFonts.nunito()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
