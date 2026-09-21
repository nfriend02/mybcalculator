import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mybcalculator/features/calculator/model/calculator_controller.dart';
import 'package:mybcalculator/pages/calculator/calculator_page.dart';

void main() {
  testWidgets('CalculatorPage taps work in mobile size', (tester) async {
    final controller = CalculatorController();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(body: CalculatorPage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('7'), findsOneWidget);

    await tester.tap(find.text('7'));
    await tester.pump();
    await tester.tap(find.text('='));
    await tester.pump();

    expect(controller.display, '7');
  });
}
