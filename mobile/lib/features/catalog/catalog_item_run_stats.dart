import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/run_result_tier.dart';

/// Aggregated stats for a catalog item id across the user’s runs.
class ItemRunStats {
  const ItemRunStats({
    required this.runCount,
    required this.bestTier,
    required this.maxWins,
  });

  final int runCount;
  final RunResultTier bestTier;
  final int maxWins;
}

/// One run per item id counts at most once (duplicate ids in a single run are ignored).
Map<String, ItemRunStats> buildItemRunStatsMap(List<RunRecord> runs) {
  final perItem = <String, List<RunRecord>>{};
  for (final run in runs) {
    for (final id in run.itemIds.toSet()) {
      (perItem[id] ??= <RunRecord>[]).add(run);
    }
  }
  final out = <String, ItemRunStats>{};
  for (final entry in perItem.entries) {
    final list = entry.value;
    var best = RunResultTier.defeat;
    var maxWins = 0;
    for (final r in list) {
      best = maxRunResultTier(best, r.resultTier);
      if (r.wins > maxWins) maxWins = r.wins;
    }
    out[entry.key] = ItemRunStats(
      runCount: list.length,
      bestTier: best,
      maxWins: maxWins,
    );
  }
  return out;
}

bool itemPassesWinHistoryFilter({
  required String itemId,
  required List<RunRecord> runs,
  required int minWins,
  required bool perfectOnly,
}) {
  return runs.any(
    (r) =>
        r.itemIds.contains(itemId) &&
        r.wins >= minWins &&
        (!perfectOnly || r.perfect),
  );
}

/// Counts runs containing [itemId] where `wins >= minWins` and optional [perfectOnly].
/// Use `minWins: 0` and `perfectOnly: false` for “all runs with this item”.
int countRunsForItemWithWinCriteria({
  required String itemId,
  required List<RunRecord> runs,
  required int minWins,
  required bool perfectOnly,
}) {
  return runs
      .where(
        (r) =>
            r.itemIds.contains(itemId) &&
            r.wins >= minWins &&
            (!perfectOnly || r.perfect),
      )
      .length;
}

/// Catalog-side filters: empty set = no constraint. Type tags use AND semantics.
bool catalogItemMatchesAttributeFilters(
  CatalogItem item, {
  required Set<String> heroTags,
  required Set<String> typeTags,
  required Set<String> rarities,
  required Set<String> sizes,
}) {
  if (heroTags.isNotEmpty && !heroTags.contains(item.heroTag)) {
    return false;
  }
  if (rarities.isNotEmpty && !rarities.contains(item.startingRarity)) {
    return false;
  }
  if (sizes.isNotEmpty) {
    final s = item.size.toString().trim();
    if (!sizes.contains(s)) return false;
  }
  if (typeTags.isNotEmpty) {
    final have = item.typeTags.toSet();
    for (final t in typeTags) {
      if (!have.contains(t)) return false;
    }
  }
  return true;
}

String normalizedCatalogSize(CatalogItem item) => item.size.toString().trim();
