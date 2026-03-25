import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/challenges/challenge_models.dart';

/// Opens Catalog tab with filters matching a challenge subgroup; run-history filter off.
/// Pops any pushed routes (e.g. [ChallengeDetailPage]) so the shell tab change is visible.
void openCatalogForChallengeFilter(
  BuildContext context, {
  required ChallengeCategoryKind kind,
  String? subgroupId,
}) {
  // Replace catalog attribute filters (clear + apply); default clearSearch: true.
  final CatalogPrefillArgs args = switch (kind) {
    ChallengeCategoryKind.fullCatalog => const CatalogPrefillArgs(
        collapseCatalogControls: true,
      ),
    ChallengeCategoryKind.heroes => CatalogPrefillArgs(
        heroTags: {subgroupId!},
        collapseCatalogControls: true,
      ),
    ChallengeCategoryKind.typeTags => CatalogPrefillArgs(
        typeTags: {subgroupId!},
        collapseCatalogControls: true,
      ),
    ChallengeCategoryKind.sizes => CatalogPrefillArgs(
        sizes: {subgroupId!},
        collapseCatalogControls: true,
      ),
    ChallengeCategoryKind.startingRarities => CatalogPrefillArgs(
        rarities: {subgroupId!},
        collapseCatalogControls: true,
      ),
  };

  if (kDebugMode) {
    debugPrint(
      'openCatalogForChallengeFilter: kind=$kind subgroupId=$subgroupId '
      'preserve=${args.preserveAttributeFilters} merge=${args.mergeAttributeFilters}',
    );
  }

  // Pop submenu routes first while [context] is still valid.
  final nav = Navigator.of(context);
  if (nav.canPop()) {
    nav.popUntil((route) => route.isFirst);
  }
  // Apply session intent immediately so pending prefill is set before frame/layout.
  // SearchPage defers consuming it to a post-frame callback so it runs after
  // AuthGate/AnimatedBuilder rebuild (avoids applying on a disposed subtree).
  sessionController.navigateToCatalogWithPrefill(args);
}
