import 'package:flutter_test/flutter_test.dart';
import 'package:mybcalculator/features/calculator/domain/calculator_engine.dart';

void main() {
  group('CalculatorEngine', () {
    test('evaluates basic arithmetic', () {
      expect(CalculatorEngine.evaluateExpression('1+2*3'), 7);
      expect(CalculatorEngine.evaluateExpression('(10-2)/4'), 2);
    });

    test('parses Korean natural language', () {
      expect(KoreanMathParser.tryParse('삼십 나누기 삼은?'), '10');
    });
  });
}
