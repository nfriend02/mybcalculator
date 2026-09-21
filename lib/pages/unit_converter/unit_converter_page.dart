import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_theme.dart';
import '../../features/unit_converter/domain/unit_converter.dart';

class UnitConverterPage extends StatefulWidget {
  const UnitConverterPage({super.key});

  @override
  State<UnitConverterPage> createState() => _UnitConverterPageState();
}

class _UnitConverterPageState extends State<UnitConverterPage> {
  final _value = TextEditingController(text: '1');
  String _mode = 'length';
  String _from = 'm';
  String _to = 'cm';
  String? _out;

  List<String> get _units => _mode == 'length'
      ? UnitConverter.lengthToMeter.keys.toList()
      : UnitConverter.weightToKg.keys.toList();

  void _convert() {
    final v = double.tryParse(_value.text) ?? 0;
    final result = _mode == 'length'
        ? UnitConverter.convertLength(v, _from, _to)
        : UnitConverter.convertWeight(v, _from, _to);
    setState(() => _out = '$v $_from = ${result.toStringAsFixed(4)} $_to');
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Text('단위 변환', style: GoogleFonts.fredoka(fontSize: 28)),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'length', label: Text('길이'), icon: Icon(Icons.straighten)),
            ButtonSegment(value: 'weight', label: Text('무게'), icon: Icon(Icons.scale)),
          ],
          selected: {_mode},
          onSelectionChanged: (s) {
            setState(() {
              _mode = s.first;
              final u = _units;
              _from = u.first;
              _to = u.length > 1 ? u[1] : u.first;
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _value,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '값',
            filled: true,
            fillColor: AppTheme.lavender.withValues(alpha: 0.4),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _unitDropdown(true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded),
            ),
            Expanded(child: _unitDropdown(false)),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _convert, child: const Text('변환')),
        if (_out != null) ...[
          const SizedBox(height: 20),
          Text(_out!, style: GoogleFonts.fredoka(fontSize: 22)),
        ],
      ],
    );
  }

  Widget _unitDropdown(bool from) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: from ? _from : _to,
      items: [
        for (final u in _units) DropdownMenuItem(value: u, child: Text(u)),
      ],
      onChanged: (v) {
        if (v == null) return;
        setState(() {
          if (from) {
            _from = v;
          } else {
            _to = v;
          }
        });
      },
      decoration: InputDecoration(
        labelText: from ? 'From' : 'To',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
