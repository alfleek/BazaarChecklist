import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/run_result_tier.dart';

RunRecord _run({
  required String id,
  required List<String> itemIds,
  required int wins,
  required bool perfect,
  RunResultTier? tier,
}) {
  return RunRecord(
    id: id,
    itemIds: itemIds,
    createdAt: DateTime.utc(2024, 1, 1),
    mode: 'ranked',
    heroId: 'hero1',
    wins: wins,
    perfect: perfect,
    resultTier: tier ?? classifyRunResult(wins: wins, perfect: perfect),
  );
}

void main() {
  group('buildItemRunStatsMap', () {
    test('counts one run per item when duplicate ids appear in itemIds', () {
      final runs = [
        _run(
          id: 'r1',
          itemIds: ['x', 'x', 'y'],
          wins: 5,
          perfect: false,
          tier: RunResultTier.bronzeVictory,
        ),
      ];
      final m = buildItemRunStatsMap(runs);
      expect(m['x']!.runCount, 1);
      expect(m['y']!.runCount, 1);
    });

    test('picks max tier and max wins across runs', () {
      final runs = [
        _run(
          id: 'r1',
          itemIds: ['x'],
          wins: 5,
          perfect: false,
          tier: RunResultTier.bronzeVictory,
        ),
        _run(
          id: 'r2',
          itemIds: ['x'],
          wins: 10,
          perfect: false,
          tier: RunResultTier.goldVictory,
        ),
      ];
      final m = buildItemRunStatsMap(runs);
      expect(m['x']!.runCount, 2);
      expect(m['x']!.bestTier, RunResultTier.goldVictory);
      expect(m['x']!.maxWins, 10);
    });
  });

  group('itemPassesWinHistoryFilter', () {
    test('requires wins and optional perfect', () {
      final runs = [
        _run(
          id: 'r1',
          itemIds: ['a'],
          wins: 10,
          perfect: true,
          tier: RunResultTier.diamondVictory,
        ),
        _run(
          id: 'r2',
          itemIds: ['b'],
          wins: 10,
          perfect: false,
          tier: RunResultTier.goldVictory,
        ),
      ];
      expect(
        itemPassesWinHistoryFilter(
          itemId: 'a',
          runs: runs,
          minWins: 10,
          perfectOnly: false,
        ),
        isTrue,
      );
      expect(
        itemPassesWinHistoryFilter(
          itemId: 'b',
          runs: runs,
          minWins: 10,
          perfectOnly: true,
        ),
        isFalse,
      );
      expect(
        itemPassesWinHistoryFilter(
          itemId: 'a',
          runs: runs,
          minWins: 10,
          perfectOnly: true,
        ),
        isTrue,
      );
    });
  });

  group('countRunsForItemWithWinCriteria', () {
    test('minWins 0 counts all runs containing item', () {
      final runs = [
        _run(
          id: 'r1',
          itemIds: ['x'],
          wins: 3,
          perfect: false,
        ),
        _run(
          id: 'r2',
          itemIds: ['x'],
          wins: 10,
          perfect: false,
        ),
      ];
      expect(
        countRunsForItemWithWinCriteria(
          itemId: 'x',
          runs: runs,
          minWins: 0,
          perfectOnly: false,
        ),
        2,
      );
    });

    test('respects minWins and perfectOnly', () {
      final runs = [
        _run(
          id: 'r1',
          itemIds: ['x'],
          wins: 10,
          perfect: true,
        ),
        _run(
          id: 'r2',
          itemIds: ['x'],
          wins: 10,
          perfect: false,
        ),
      ];
      expect(
        countRunsForItemWithWinCriteria(
          itemId: 'x',
          runs: runs,
          minWins: 10,
          perfectOnly: true,
        ),
        1,
      );
    });
  });

  group('catalogItemMatchesAttributeFilters', () {
    final item = CatalogItem(
      id: 'i1',
      name: 'Test',
      typeTags: const ['Burn', 'Melee'],
      heroTag: 'Vanessa',
      startingRarity: 'Rare',
      size: 'Large',
      active: true,
    );

    test('type tags use AND semantics', () {
      expect(
        catalogItemMatchesAttributeFilters(
          item,
          heroTags: {},
          typeTags: {'Burn', 'Melee'},
          rarities: {},
          sizes: {},
        ),
        isTrue,
      );
      expect(
        catalogItemMatchesAttributeFilters(
          item,
          heroTags: {},
          typeTags: {'Burn', 'Ice'},
          rarities: {},
          sizes: {},
        ),
        isFalse,
      );
    });

    test('hero rarity and size filters', () {
      expect(
        catalogItemMatchesAttributeFilters(
          item,
          heroTags: {'Vanessa'},
          typeTags: {},
          rarities: {},
          sizes: {},
        ),
        isTrue,
      );
      expect(
        catalogItemMatchesAttributeFilters(
          item,
          heroTags: {'Other'},
          typeTags: {},
          rarities: {},
          sizes: {},
        ),
        isFalse,
      );
      expect(
        catalogItemMatchesAttributeFilters(
          item,
          heroTags: {},
          typeTags: {},
          rarities: {'Rare'},
          sizes: {},
        ),
        isTrue,
      );
      expect(
        catalogItemMatchesAttributeFilters(
          item,
          heroTags: {},
          typeTags: {},
          rarities: {},
          sizes: {'Large'},
        ),
        isTrue,
      );
    });
  });

  group('runResultTierRank', () {
    test('diamond is above gold', () {
      expect(
        runResultTierRank(RunResultTier.diamondVictory) >
            runResultTierRank(RunResultTier.goldVictory),
        isTrue,
      );
    });
  });
}
