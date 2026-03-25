import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/challenges/challenge_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('navigateToCatalogWithPrefill sets pending args and catalog tab index', () {
    final c = SessionController();
    c.navigateToCatalogWithPrefill(
      const CatalogPrefillArgs(
        heroTags: {'Vanessa'},
        typeTags: {'Weapon'},
      ),
    );
    expect(c.preferredTabIndex, 1);
    expect(c.pendingCatalogPrefill, isNotNull);
    expect(c.pendingCatalogPrefill!.heroTags, {'Vanessa'});
    expect(c.pendingCatalogPrefill!.typeTags, {'Weapon'});
    expect(c.pendingCatalogPrefill!.preserveAttributeFilters, false);
    expect(c.pendingCatalogPrefill!.mergeAttributeFilters, false);
    c.clearPendingCatalogPrefill();
    expect(c.pendingCatalogPrefill, isNull);
  });

  test('CatalogPrefillArgs supports preserve-only (full-catalog tab switch)', () {
    final c = SessionController();
    c.navigateToCatalogWithPrefill(
      const CatalogPrefillArgs(
        clearSearch: false,
        preserveAttributeFilters: true,
      ),
    );
    expect(c.pendingCatalogPrefill!.preserveAttributeFilters, true);
    expect(c.pendingCatalogPrefill!.mergeAttributeFilters, false);
  });

  test('CatalogPrefillArgs supports merge (subgroup View in Catalog)', () {
    final c = SessionController();
    c.navigateToCatalogWithPrefill(
      const CatalogPrefillArgs(
        heroTags: {'Vanessa'},
        clearSearch: false,
        mergeAttributeFilters: true,
      ),
    );
    expect(c.pendingCatalogPrefill!.mergeAttributeFilters, true);
    expect(c.pendingCatalogPrefill!.preserveAttributeFilters, false);
    expect(c.pendingCatalogPrefill!.heroTags, {'Vanessa'});
  });

  test('persistShellTabIndex stores last shell tab without notify', () {
    final c = SessionController();
    expect(c.shellTabIndex, 0);
    c.persistShellTabIndex(2);
    expect(c.shellTabIndex, 2);
    c.persistShellTabIndex(2);
    expect(c.shellTabIndex, 2);
  });

  test('challengeChecklistTier persists on SessionController', () {
    final c = SessionController();
    expect(c.challengeChecklistTier, ChallengeChecklistTier.gold);
    c.setChallengeChecklistTier(ChallengeChecklistTier.bronze);
    expect(c.challengeChecklistTier, ChallengeChecklistTier.bronze);
    c.setChallengeChecklistTier(ChallengeChecklistTier.bronze);
    expect(c.challengeChecklistTier, ChallengeChecklistTier.bronze);
  });

  test('takePendingOpenAccount is one-shot', () {
    final c = SessionController();
    expect(c.takePendingOpenAccount(), false);
    c.requestOpenAccount();
    expect(c.takePendingOpenAccount(), true);
    expect(c.takePendingOpenAccount(), false);
  });
}
