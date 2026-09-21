import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mybcalculator/features/calculator/model/calculator_controller.dart';
import 'package:mybcalculator/features/calculator/ui/calculator_pad.dart';

void main() {
  testWidgets('CalculatorPad digits and equals update display', (tester) async {
    final controller = CalculatorController();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 640,
              child: CalculatorPad(),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('='));
    await tester.pump();

    expect(controller.display, '3');
  });
}
