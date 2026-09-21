import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../features/currency/domain/currency_service.dart';

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
    return ListView(
      children: [
        Text('환율 변환', style: GoogleFonts.fredoka(fontSize: 28)),
        const SizedBox(height: 8),
        Text(
          '예: "10달러면 한국돈으로 얼마지?"',
          style: GoogleFonts.nunito(
            color: AppTheme.ink.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '금액',
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.85),
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
            fillColor: AppTheme.butter.withValues(alpha: 0.5),
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
              color: AppTheme.mint.withValues(alpha: 0.7),
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
    );
  }
}
