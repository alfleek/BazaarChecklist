import 'package:mobile/features/runs/run_result_tier.dart';

/// Win threshold for checklist progress (at-least semantics via [itemMeetsChallengeTier]).
enum ChallengeChecklistTier {
  bronze,
  silver,
  gold,
  perfect,
}

extension ChallengeChecklistTierLabels on ChallengeChecklistTier {
  String get label => switch (this) {
        ChallengeChecklistTier.bronze => 'Bronze',
        ChallengeChecklistTier.silver => 'Silver',
        ChallengeChecklistTier.gold => 'Gold',
        ChallengeChecklistTier.perfect => 'Perfect',
      };
}

/// Top-level category on the Challenges hub (drill-down lists sub-checklists).
enum ChallengeCategoryKind {
  fullCatalog,
  heroes,
  typeTags,
  sizes,
  startingRarities,
}

extension ChallengeCategoryKindLabels on ChallengeCategoryKind {
  String get title => switch (this) {
        ChallengeCategoryKind.fullCatalog => 'Every item',
        ChallengeCategoryKind.heroes => 'Heroes',
        ChallengeCategoryKind.typeTags => 'Item tags',
        ChallengeCategoryKind.sizes => 'Sizes',
        ChallengeCategoryKind.startingRarities => 'Starting tiers',
      };

  String get subtitle => switch (this) {
        ChallengeCategoryKind.fullCatalog =>
          'All items at this win level.',
        ChallengeCategoryKind.heroes => 'Per hero tag.',
        ChallengeCategoryKind.typeTags =>
          'Per tag (an item can count toward several).',
        ChallengeCategoryKind.sizes => 'Per size.',
        ChallengeCategoryKind.startingRarities => 'Per starting rarity.',
      };
}

/// True if the user’s best result for an item is at least [goal] tier.
bool itemMeetsChallengeTier(RunResultTier bestTier, ChallengeChecklistTier goal) {
  final minRank = switch (goal) {
    ChallengeChecklistTier.bronze => runResultTierRank(RunResultTier.bronzeVictory),
    ChallengeChecklistTier.silver => runResultTierRank(RunResultTier.silverVictory),
    ChallengeChecklistTier.gold => runResultTierRank(RunResultTier.goldVictory),
    ChallengeChecklistTier.perfect => runResultTierRank(RunResultTier.diamondVictory),
  };
  return runResultTierRank(bestTier) >= minRank;
}
