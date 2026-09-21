import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../features/currency/domain/currency_service.dart';
import '../../shared/ui/widgets/feature_scaffold.dart';

class CurrencyPage extends StatefulWidget {
  const CurrencyPage({super.key});

  @override
  State<CurrencyPage> createState() => _CurrencyPageState();
}

class _CurrencyPageState extends State<CurrencyPage> {
  final _amount = TextEditingController(text: '10');
  final _service = CurrencyService();
  String _from = 'USD';
  String? _result;
  bool _loading = false;

  static const _codes = ['USD', 'EUR', 'JPY', 'CNY', 'GBP'];

  Future<void> _convert() async {
    setState(() => _loading = true);
    try {
      final amount = double.tryParse(_amount.text) ?? 0;
      final krw = await _service.convert(amount: amount, from: _from);
      setState(() {
        _result =
            '$amount $_from = ${krw.toStringAsFixed(0)} KRW';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: '환율 변환',
      subtitle: '달러·엔·유로를 원화로 바로 환산',
      emoji: '💱',
      accent: AppTheme.butter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '금액',
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: _from,
            items: [
              for (final c in _codes)
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _from = v ?? 'USD'),
            decoration: InputDecoration(
              labelText: '통화',
              filled: true,
              fillColor: AppTheme.butter.withValues(alpha: 0.55),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loading ? null : _convert,
            child: Text(_loading ? '변환 중…' : '원화로 변환'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.mint.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _result!,
                style: GoogleFonts.fredoka(fontSize: 22),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
