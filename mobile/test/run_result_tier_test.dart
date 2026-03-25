import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/runs/run_result_tier.dart';

void main() {
  group('classifyRunResult', () {
    test('0-3 wins is defeat', () {
      expect(classifyRunResult(wins: 0, perfect: false), RunResultTier.defeat);
      expect(classifyRunResult(wins: 3, perfect: false), RunResultTier.defeat);
    });

    test('4-6 wins is bronze', () {
      expect(classifyRunResult(wins: 4, perfect: false), RunResultTier.bronzeVictory);
      expect(classifyRunResult(wins: 6, perfect: false), RunResultTier.bronzeVictory);
    });

    test('7-9 wins is silver', () {
      expect(classifyRunResult(wins: 7, perfect: false), RunResultTier.silverVictory);
      expect(classifyRunResult(wins: 9, perfect: false), RunResultTier.silverVictory);
    });

    test('10 wins without perfect is gold', () {
      expect(classifyRunResult(wins: 10, perfect: false), RunResultTier.goldVictory);
    });

    test('10 wins with perfect is diamond', () {
      expect(classifyRunResult(wins: 10, perfect: true), RunResultTier.diamondVictory);
    });
  });

  group('perfect toggle visibility rule', () {
    test('only 10 wins allows perfect diamond path', () {
      expect(classifyRunResult(wins: 9, perfect: true), RunResultTier.silverVictory);
      expect(classifyRunResult(wins: 10, perfect: true), RunResultTier.diamondVictory);
    });
  });
}
