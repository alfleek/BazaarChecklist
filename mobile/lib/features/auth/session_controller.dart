import 'package:flutter/foundation.dart';
import 'package:mobile/features/challenges/challenge_models.dart';

/// Optional filters applied when navigating to Catalog from Challenges.
///
/// - Default (replace): clears attribute filter sets and applies [heroTags], etc.
/// - [mergeAttributeFilters]: adds non-empty args into existing sets; other dimensions
///   are left unchanged (used for subgroup "View in Catalog").
/// - [preserveAttributeFilters]: does not change hero/tag/rarity/size selections
///   (used for full-catalog navigation — tab switch only).
class CatalogPrefillArgs {
  const CatalogPrefillArgs({
    this.heroTags = const {},
    this.typeTags = const {},
    this.hiddenTags = const {},
    this.rarities = const {},
    this.sizes = const {},
    this.clearSearch = true,
    this.preserveAttributeFilters = false,
    this.mergeAttributeFilters = false,
    this.collapseCatalogControls = false,
  });

  final Set<String> heroTags;
  final Set<String> typeTags;
  final Set<String> hiddenTags;
  final Set<String> rarities;
  final Set<String> sizes;
  final bool clearSearch;

  /// When true, do not modify hero/tag/rarity/size filter sets (only tab + optional search).
  final bool preserveAttributeFilters;

  /// When true, merge non-empty [heroTags]/etc. into existing sets instead of replacing all.
  final bool mergeAttributeFilters;

  /// When true, [SearchPage] hides search + filter UI after applying (e.g. Challenges → Catalog).
  final bool collapseCatalogControls;
}

class SessionController extends ChangeNotifier {
  bool _isGuest = false;
  int? _preferredTabIndex;
  bool _pendingOpenAccount = false;
  CatalogPrefillArgs? _pendingCatalogPrefill;
  ChallengeChecklistTier _challengeChecklistTier = ChallengeChecklistTier.gold;
  /// Last selected shell tab: 0 Runs, 1 Catalog, 2 Challenges. Not notified — survives
  /// [AppShellPage] recreation when [AuthGate] rebuilds (e.g. session notify).
  int _shellTabIndex = 0;

  bool get isGuest => _isGuest;
  int? get preferredTabIndex => _preferredTabIndex;

  CatalogPrefillArgs? get pendingCatalogPrefill => _pendingCatalogPrefill;

  int get shellTabIndex => _shellTabIndex;

  /// Persists bottom tab without notifying (avoids rebuild loops). Call whenever the
  /// visible tab changes so a new [AppShellPage] can restore it when `preferredTabIndex` is null.
  void persistShellTabIndex(int index) {
    assert(index >= 0 && index <= 2, 'shell tab index must be 0–2');
    if (_shellTabIndex == index) return;
    _shellTabIndex = index;
  }

  /// Shared between Challenges hub and category drill-down so the win dropdown stays in sync.
  ChallengeChecklistTier get challengeChecklistTier => _challengeChecklistTier;

  /// Tier-only updates (no [notifyListeners]) so [AuthGate] does not rebuild the whole
  /// shell and reset [StreamBuilder]s. Listen with [Listenable.merge] or this notifier.
  final ValueNotifier<ChallengeChecklistTier> challengeTierListenable =
      ValueNotifier<ChallengeChecklistTier>(ChallengeChecklistTier.gold);

  void setChallengeChecklistTier(ChallengeChecklistTier value) {
    if (_challengeChecklistTier == value) return;
    _challengeChecklistTier = value;
    challengeTierListenable.value = value;
  }

  void continueAsGuest() {
    _isGuest = true;
    notifyListeners();
  }

  void clearGuest() {
    if (!_isGuest) return;
    _isGuest = false;
    notifyListeners();
  }

  void setPreferredTabIndex(int index) {
    _preferredTabIndex = index;
  }

  void clearPreferredTabIndex() {
    _preferredTabIndex = null;
  }

  /// After sign-in / guest choice flows, open Account as a pushed route (not a tab).
  void requestOpenAccount() {
    _pendingOpenAccount = true;
    notifyListeners();
  }

  bool takePendingOpenAccount() {
    if (!_pendingOpenAccount) return false;
    _pendingOpenAccount = false;
    return true;
  }

  /// Switch to Catalog tab and apply filters; run-history filter stays off.
  void navigateToCatalogWithPrefill(CatalogPrefillArgs args) {
    assert(
      !(args.preserveAttributeFilters && args.mergeAttributeFilters),
      'CatalogPrefillArgs: preserveAttributeFilters and mergeAttributeFilters are mutually exclusive.',
    );
    _pendingCatalogPrefill = args;
    _preferredTabIndex = 1;
    persistShellTabIndex(1);
    if (kDebugMode) {
      debugPrint(
        'SessionController.navigateToCatalogWithPrefill: '
        'preserve=${args.preserveAttributeFilters} merge=${args.mergeAttributeFilters} '
        'clearSearch=${args.clearSearch} collapseControls=${args.collapseCatalogControls} '
        'hero=${args.heroTags} type=${args.typeTags} '
        'hidden=${args.hiddenTags} rarity=${args.rarities} size=${args.sizes}',
      );
    }
    notifyListeners();
  }

  void clearPendingCatalogPrefill() {
    _pendingCatalogPrefill = null;
  }
}

final sessionController = SessionController();
