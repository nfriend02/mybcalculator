import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../entities/weather/weather_snapshot.dart';
import '../../features/weather/domain/weather_service.dart';
import '../../shared/ui/widgets/feature_scaffold.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final _city = TextEditingController(text: '서울');
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
    return FeatureScaffold(
      title: '날씨 조회',
      subtitle: '서울·요코하마·Tokyo 등 도시 이름으로',
      emoji: '🌤️',
      accent: AppTheme.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                    AppTheme.sky.withValues(alpha: 0.95),
                    AppTheme.lavender.withValues(alpha: 0.75),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  const Text('🌤️', style: TextStyle(fontSize: 48)),
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
                    Text(
                      '습도 ${_snap!.humidity}%',
                      style: GoogleFonts.nunito(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
