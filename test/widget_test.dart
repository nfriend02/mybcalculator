import 'package:flutter_test/flutter_test.dart';
import 'package:mybcalculator/features/calculator/domain/calculator_engine.dart';
import 'package:mybcalculator/features/calculator/domain/fx_money_parser.dart';
import 'package:mybcalculator/features/currency/domain/currency_service.dart';

void main() {
  group('CalculatorEngine', () {
    test('evaluates basic arithmetic', () {
      expect(CalculatorEngine.evaluateExpression('1+2*3'), 7);
      expect(CalculatorEngine.evaluateExpression('(10-2)/4'), 2);
    });

    test('parses Korean natural language', () {
      expect(KoreanMathParser.tryParse('삼십 나누기 삼은?'), '10');
    });

    test('parses multi-item Korean money sentence', () {
      const q =
          '갈비탕 한그릇에 만이천원짜리를 3명에게 사주고, 커피 4,500원에 세 잔을 사 주었어. 전부 더하면 얼마이지?';
      expect(KoreanMathParser.tryParse(q), '49500');
    });

    test('sums coffee and kalguksu without treating price as qty', () {
      const q = '오늘 점심 커피 2,000원 칼국수 만원짜리를 먹었어';
      expect(KoreanMathParser.tryParse(q), '12000');
    });

    test('parses N만 원 forms (4만 + 3만)', () {
      const q = '어제 저녁 쇠고기이 두근에 4만 원 그리고 야채 3만 원어치 샀어';
      expect(KoreanMathParser.tryParse(q), '70000');
    });

    test('parseMoneyAmount handles N만', () {
      expect(KoreanMathParser.parseMoneyAmount('4만'), 40000);
      expect(KoreanMathParser.parseMoneyAmount('만이천'), 12000);
    });

    test('dollar furniture sentence is not misread as 59', () {
      const q = '오늘 30달러짜리 가구를 구매하고 10달러 배송비를 지불했어';
      expect(KoreanMathParser.tryParse(q), isNull);
    });
  });

  group('FxMoneyParser', () {
    final demoFx = CurrencyService(
      fixedSnapshot: const FxRateSnapshot(
        rates: CurrencyService.demoToKrw,
        source: 'live',
        label: '오늘 환율',
      ),
    );

    test('converts USD and JPY to KRW with rate notes', () async {
      final fx = await FxMoneyParser.tryParse(
        '미국 달러 10달러 그리고 일본 엔 1000엔',
        currency: demoFx,
      );
      expect(fx, isNotNull);
      // 10*1350 + 1000*9.1 = 13500 + 9100 = 22600
      expect(fx!.krwTotal, '22600');
      expect(
        fx.rateNotes.any((n) => n.contains('달러') && n.contains('오늘 환율')),
        isTrue,
      );
      expect(
        fx.rateNotes.any((n) => n.contains('엔') && n.contains('오늘 환율')),
        isTrue,
      );
    });

    test('converts 4만 달러', () async {
      final fx = await FxMoneyParser.tryParse(
        '어제 쇠고기 4만 미국 달러 샀어',
        currency: demoFx,
      );
      expect(fx, isNotNull);
      expect(fx!.krwTotal, '54000000'); // 40000 * 1350
      expect(
        fx.rateNotes.single,
        '1달러의 오늘 환율인 1,350원을 적용했습니다',
      );
    });

    test('30달러짜리 + 10달러 shipping', () async {
      const q = '오늘 30달러짜리 가구를 구매하고 10달러 배송비를 지불했어';
      final fx = await FxMoneyParser.tryParse(q, currency: demoFx);
      expect(fx, isNotNull);
      expect(fx!.krwTotal, '54000'); // (30+10)*1350
      expect(
        fx.rateNotes.single,
        '1달러의 오늘 환율인 1,350원을 적용했습니다',
      );
    });

    test('previous close label in rate note', () async {
      final closeFx = CurrencyService(
        fixedSnapshot: const FxRateSnapshot(
          rates: CurrencyService.demoToKrw,
          source: 'previous_close',
          label: '직전 종가',
        ),
      );
      final fx = await FxMoneyParser.tryParse(
        '20달러',
        currency: closeFx,
      );
      expect(fx, isNotNull);
      expect(
        fx!.rateNotes.single,
        '1달러의 직전 종가인 1,350원을 적용했습니다',
      );
    });
  });
}
