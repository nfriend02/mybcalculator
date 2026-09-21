import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:mybcalculator/features/calculator/model/calculator_controller.dart';
import 'package:mybcalculator/features/calculator/ui/calculator_pad.dart';
import 'package:mybcalculator/pages/home/home_page.dart';

void main() {
  testWidgets('CalculatorPad digits and equals update display', (tester) async {
    final controller = CalculatorController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 640,
            child: CalculatorPad(controller: controller),
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

  testWidgets('HomePage shows sentence panel and keypad', (tester) async {
    final controller = CalculatorController();
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ChangeNotifierProvider<CalculatorController>.value(
        value: controller,
        child: const MaterialApp(
          home: Scaffold(body: HomePage()),
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('나의 만능 AI 계산기'), findsOneWidget);
    expect(find.text('키패드'), findsOneWidget);
    expect(find.text('계산하기'), findsOneWidget);
  });
}
