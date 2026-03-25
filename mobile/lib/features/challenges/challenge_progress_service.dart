import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/challenges/challenge_models.dart';
import 'package:mobile/features/runs/run_result_tier.dart';

/// Aggregated checklist counts for UI (percentage bar).
class ChecklistProgress {
  const ChecklistProgress({
    required this.completed,
    required this.total,
  });

  final int completed;
  final int total;

  double get ratio => total <= 0 ? 0 : completed / total;

  String get fractionLabel => '$completed / $total';
}

/// One row in a grouped challenge list (e.g. hero "Vanessa").
class SubgroupProgress {
  const SubgroupProgress({
    required this.id,
    required this.label,
    required this.progress,
  });

  final String id;
  final String label;
  final ChecklistProgress progress;
}

/// Sum subgroup numerators/denominators (valid for disjoint partitions; tag groups may double-count).
ChecklistProgress rollupSumSubgroups(List<SubgroupProgress> subgroups) {
  var c = 0;
  var t = 0;
  for (final s in subgroups) {
    c += s.progress.completed;
    t += s.progress.total;
  }
  return ChecklistProgress(completed: c, total: t);
}

ChecklistProgress computeFullCatalogProgress({
  required List<CatalogItem> catalog,
  required Map<String, ItemRunStats> stats,
  required ChallengeChecklistTier tier,
}) {
  var completed = 0;
  final total = catalog.length;
  for (final item in catalog) {
    final best = stats[item.id]?.bestTier ?? RunResultTier.defeat;
    if (itemMeetsChallengeTier(best, tier)) {
      completed++;
    }
  }
  return ChecklistProgress(completed: completed, total: total);
}

List<SubgroupProgress> computeHeroSubgroupProgress({
  required List<CatalogItem> catalog,
  required Map<String, ItemRunStats> stats,
  required ChallengeChecklistTier tier,
}) {
  final heroes = <String>{};
  for (final item in catalog) {
    final h = item.heroTag.trim();
    if (h.isNotEmpty) heroes.add(h);
  }
  final sorted = heroes.toList()..sort();
  return sorted.map((hero) {
    final items = catalog.where((i) => i.heroTag.trim() == hero).toList();
    var done = 0;
    for (final item in items) {
      final best = stats[item.id]?.bestTier ?? RunResultTier.defeat;
      if (itemMeetsChallengeTier(best, tier)) done++;
    }
    return SubgroupProgress(
      id: hero,
      label: hero,
      progress: ChecklistProgress(completed: done, total: items.length),
    );
  }).toList(growable: false);
}

List<SubgroupProgress> computeTypeTagSubgroupProgress({
  required List<CatalogItem> catalog,
  required Map<String, ItemRunStats> stats,
  required ChallengeChecklistTier tier,
}) {
  final tags = <String>{};
  for (final item in catalog) {
    tags.addAll(item.typeTags.map((t) => t.trim()).where((t) => t.isNotEmpty));
  }
  final sorted = tags.toList()..sort();
  return sorted.map((tag) {
    final items = catalog.where((i) => i.typeTags.contains(tag)).toList();
    var done = 0;
    for (final item in items) {
      final best = stats[item.id]?.bestTier ?? RunResultTier.defeat;
      if (itemMeetsChallengeTier(best, tier)) done++;
    }
    return SubgroupProgress(
      id: tag,
      label: tag,
      progress: ChecklistProgress(completed: done, total: items.length),
    );
  }).toList(growable: false);
}

List<SubgroupProgress> computeSizeSubgroupProgress({
  required List<CatalogItem> catalog,
  required Map<String, ItemRunStats> stats,
  required ChallengeChecklistTier tier,
}) {
  final sizes = <String>{};
  for (final item in catalog) {
    final s = normalizedCatalogSize(item);
    if (s.isNotEmpty) sizes.add(s);
  }
  final sorted = sizes.toList()..sort();
  return sorted.map((size) {
    final items = catalog
        .where((i) => normalizedCatalogSize(i) == size)
        .toList();
    var done = 0;
    for (final item in items) {
      final best = stats[item.id]?.bestTier ?? RunResultTier.defeat;
      if (itemMeetsChallengeTier(best, tier)) done++;
    }
    return SubgroupProgress(
      id: size,
      label: size,
      progress: ChecklistProgress(completed: done, total: items.length),
    );
  }).toList(growable: false);
}

List<SubgroupProgress> computeStartingRaritySubgroupProgress({
  required List<CatalogItem> catalog,
  required Map<String, ItemRunStats> stats,
  required ChallengeChecklistTier tier,
}) {
  final rarities = <String>{};
  for (final item in catalog) {
    final r = item.startingRarity.trim();
    if (r.isNotEmpty) rarities.add(r);
  }
  final sorted = rarities.toList()..sort();
  return sorted.map((rarity) {
    final items = catalog.where((i) => i.startingRarity.trim() == rarity).toList();
    var done = 0;
    for (final item in items) {
      final best = stats[item.id]?.bestTier ?? RunResultTier.defeat;
      if (itemMeetsChallengeTier(best, tier)) done++;
    }
    return SubgroupProgress(
      id: rarity,
      label: rarity,
      progress: ChecklistProgress(completed: done, total: items.length),
    );
  }).toList(growable: false);
}
