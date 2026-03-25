import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/challenges/challenge_models.dart';
import 'package:mobile/features/challenges/challenge_progress_service.dart';
import 'package:mobile/features/runs/run_result_tier.dart';

void main() {
  group('itemMeetsChallengeTier', () {
    test('bronze accepts bronze and above', () {
      expect(
        itemMeetsChallengeTier(RunResultTier.defeat, ChallengeChecklistTier.bronze),
        false,
      );
      expect(
        itemMeetsChallengeTier(RunResultTier.bronzeVictory, ChallengeChecklistTier.bronze),
        true,
      );
      expect(
        itemMeetsChallengeTier(RunResultTier.diamondVictory, ChallengeChecklistTier.bronze),
        true,
      );
    });

    test('gold accepts gold and perfect', () {
      expect(
        itemMeetsChallengeTier(RunResultTier.silverVictory, ChallengeChecklistTier.gold),
        false,
      );
      expect(
        itemMeetsChallengeTier(RunResultTier.goldVictory, ChallengeChecklistTier.gold),
        true,
      );
      expect(
        itemMeetsChallengeTier(RunResultTier.diamondVictory, ChallengeChecklistTier.gold),
        true,
      );
    });

    test('perfect accepts only diamond', () {
      expect(
        itemMeetsChallengeTier(RunResultTier.goldVictory, ChallengeChecklistTier.perfect),
        false,
      );
      expect(
        itemMeetsChallengeTier(RunResultTier.diamondVictory, ChallengeChecklistTier.perfect),
        true,
      );
    });
  });

  group('computeFullCatalogProgress', () {
    final catalog = [
      const CatalogItem(
        id: 'a',
        name: 'A',
        typeTags: [],
        heroTag: 'H',
        startingRarity: 'r',
        size: 'Small',
        active: true,
      ),
      const CatalogItem(
        id: 'b',
        name: 'B',
        typeTags: [],
        heroTag: 'H',
        startingRarity: 'r',
        size: 'Small',
        active: true,
      ),
    ];

    test('counts items meeting tier from stats', () {
      final stats = <String, ItemRunStats>{
        'a': const ItemRunStats(
          runCount: 1,
          bestTier: RunResultTier.goldVictory,
          maxWins: 10,
        ),
        'b': const ItemRunStats(
          runCount: 1,
          bestTier: RunResultTier.defeat,
          maxWins: 0,
        ),
      };
      final p = computeFullCatalogProgress(
        catalog: catalog,
        stats: stats,
        tier: ChallengeChecklistTier.gold,
      );
      expect(p.total, 2);
      expect(p.completed, 1);
      expect(p.ratio, 0.5);
    });
  });

  group('rollupSumSubgroups', () {
    test('sums numerators and denominators', () {
      final roll = rollupSumSubgroups([
        const SubgroupProgress(
          id: 'x',
          label: 'X',
          progress: ChecklistProgress(completed: 2, total: 4),
        ),
        const SubgroupProgress(
          id: 'y',
          label: 'Y',
          progress: ChecklistProgress(completed: 1, total: 3),
        ),
      ]);
      expect(roll.completed, 3);
      expect(roll.total, 7);
    });
  });
}
