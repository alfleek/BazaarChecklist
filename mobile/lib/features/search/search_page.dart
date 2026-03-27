import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_detail_page.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/catalog/catalog_search_utils.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/run_result_tier.dart';
import 'package:mobile/features/runs/run_tier_visual.dart';
import 'package:mobile/features/runs/runs_repository.dart';
import 'package:mobile/features/shared/ui/labeled_slider_row.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({
    required this.isGuest,
    super.key,
    this.userId,
  });

  final bool isGuest;
  final String? userId;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _searchQueryLower = '';
  String _pendingSearchQuery = '';
  Timer? _searchDebounce;

  bool _catalogPrefillApplyScheduled = false;
  bool _catalogControlsExpanded = true;

  final ScrollController _catalogScrollController = ScrollController();
  double _browseScrollOffset = 0;
  double _searchScrollOffset = 0;

  final Set<String> _selectedHeroTags = {};
  final Set<String> _selectedTypeTags = {};
  final Set<String> _selectedHiddenTags = {};
  final Set<String> _selectedRarities = {};
  final Set<String> _selectedSizes = {};

  String _sortKey = 'alphabetical';
  bool _sortAscending = true;
  bool _winFilterEnabled = false;
  int _minWins = 10;
  bool _perfectOnly = false;

  static const _surfaceInner = Color(0xFF241516);
  static const _muted = Color(0xFFC3B5A0);
  static const _divider = Color(0xFF5B3A1F);

  /// Bottom inset so catalog can scroll clear of the floating bottom nav.
  EdgeInsets _catalogListPadding(BuildContext context) {
    const horizontal = 16.0;
    const top = 16.0;
    const bottomBase = 16.0;
    const buffer = 100.0;
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      bottomBase + MediaQuery.paddingOf(context).bottom + buffer,
    );
  }

  @override
  void initState() {
    super.initState();
    sessionController.addListener(_onSessionChangedForCatalogPrefill);
    _catalogScrollController.addListener(_rememberScrollOffsetByMode);
    _scheduleCatalogPrefillApply();
  }

  /// Runs after the current frame so [sessionController] notifies from AuthGate’s
  /// [AnimatedBuilder] finish rebuilding first; avoids applying prefill while the
  /// catalog [State] is torn down or not yet mounted for the new shell frame.
  void _scheduleCatalogPrefillApply() {
    if (_catalogPrefillApplyScheduled) return;
    _catalogPrefillApplyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _catalogPrefillApplyScheduled = false;
      if (!mounted) return;
      _applyCatalogPrefillIfPending();
    });
  }

  void _onSessionChangedForCatalogPrefill() {
    _scheduleCatalogPrefillApply();
  }

  void _applyCatalogPrefillIfPending() {
    final args = sessionController.pendingCatalogPrefill;
    if (args == null) return;
    if (!mounted) return;

    assert(
      !(args.preserveAttributeFilters && args.mergeAttributeFilters),
      'CatalogPrefillArgs: preserveAttributeFilters and mergeAttributeFilters are mutually exclusive.',
    );

    if (kDebugMode) {
      debugPrint(
        'SearchPage._applyCatalogPrefillIfPending: '
        'preserve=${args.preserveAttributeFilters} merge=${args.mergeAttributeFilters} '
        'clearSearch=${args.clearSearch}',
      );
    }

    setState(() {
      if (args.preserveAttributeFilters) {
        // Tab-only navigation from Challenges (e.g. full catalog CTA).
      } else if (args.mergeAttributeFilters) {
        if (args.heroTags.isNotEmpty) {
          _selectedHeroTags.addAll(args.heroTags);
        }
        if (args.typeTags.isNotEmpty) {
          _selectedTypeTags.addAll(args.typeTags);
        }
        if (args.hiddenTags.isNotEmpty) {
          _selectedHiddenTags.addAll(args.hiddenTags);
        }
        if (args.rarities.isNotEmpty) {
          _selectedRarities.addAll(args.rarities);
        }
        if (args.sizes.isNotEmpty) {
          _selectedSizes.addAll(args.sizes);
        }
      } else {
        _selectedHeroTags
          ..clear()
          ..addAll(args.heroTags);
        _selectedTypeTags
          ..clear()
          ..addAll(args.typeTags);
        _selectedHiddenTags
          ..clear()
          ..addAll(args.hiddenTags);
        _selectedRarities
          ..clear()
          ..addAll(args.rarities);
        _selectedSizes
          ..clear()
          ..addAll(args.sizes);
      }
      _winFilterEnabled = false;
      _perfectOnly = false;
      if (args.clearSearch) {
        _searchController.clear();
        _searchQuery = '';
        _searchQueryLower = '';
        _pendingSearchQuery = '';
      }
      if (args.collapseCatalogControls) {
        _catalogControlsExpanded = false;
      }
    });
    sessionController.clearPendingCatalogPrefill();
  }

  // Catalog loading is stream-driven via [catalogRepository.watchActiveCatalogItems].

  @override
  void dispose() {
    sessionController.removeListener(_onSessionChangedForCatalogPrefill);
    _catalogScrollController.removeListener(_rememberScrollOffsetByMode);
    _searchDebounce?.cancel();
    _searchController.dispose();
    _catalogScrollController.dispose();
    super.dispose();
  }

  void _rememberScrollOffsetByMode() {
    if (!_catalogScrollController.hasClients) return;
    final offset = _catalogScrollController.offset;
    if (_searchQueryLower.isEmpty) {
      _browseScrollOffset = offset;
    } else {
      _searchScrollOffset = offset;
    }
  }

  void _applySearchQueryWithScrollRestore(String rawQuery) {
    final nextQuery = rawQuery;
    final nextNorm = normalizeCatalogSearchQuery(nextQuery);
    final prevModeWasSearch = _searchQueryLower.isNotEmpty;
    final nextModeIsSearch = nextNorm.isNotEmpty;

    _rememberScrollOffsetByMode();

    setState(() {
      _searchQuery = nextQuery;
      _searchQueryLower = nextNorm;
    });

    if (prevModeWasSearch == nextModeIsSearch) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_catalogScrollController.hasClients) return;
      final target = nextModeIsSearch ? _searchScrollOffset : _browseScrollOffset;
      final pos = _catalogScrollController.position;
      final clamped = target.clamp(0, pos.maxScrollExtent).toDouble();
      if ((_catalogScrollController.offset - clamped).abs() < 1) return;
      _catalogScrollController.jumpTo(clamped);
    });
  }

  bool get _hasActiveFilters {
    return _selectedHeroTags.isNotEmpty ||
        _selectedTypeTags.isNotEmpty ||
        _selectedHiddenTags.isNotEmpty ||
        _selectedRarities.isNotEmpty ||
        _selectedSizes.isNotEmpty ||
        _winFilterEnabled ||
        _sortKey != 'alphabetical' ||
        !_sortAscending ||
        _searchQuery.trim().isNotEmpty;
  }

  void _clearFilters() {
    setState(() {
      _selectedHeroTags.clear();
      _selectedTypeTags.clear();
      _selectedHiddenTags.clear();
      _selectedRarities.clear();
      _selectedSizes.clear();
      _winFilterEnabled = false;
      _minWins = 10;
      _perfectOnly = false;
      _sortKey = 'alphabetical';
      _sortAscending = true;
      _pendingSearchQuery = '';
    });
    _searchController.clear();
    _applySearchQueryWithScrollRestore('');
  }

  List<CatalogItem> _applySearch(
    List<CatalogItem> items,
    String query,
    Map<String, CatalogItemSearchFields> fieldsById,
  ) {
    final qLower = normalizeCatalogSearchQuery(query);
    if (qLower.isEmpty) return items;
    return items.where((item) {
      final f = fieldsById[item.id] ?? buildCatalogItemSearchFields(item);
      return f.matchesLower(qLower);
    }).toList(growable: false);
  }

  // No search prefetching needed: we load the full catalog stream once.

  int _compareByWinsSort(
    CatalogItem a,
    CatalogItem b,
    Map<String, ItemRunStats> stats,
    bool ascending,
  ) {
    int nameCmp(CatalogItem x, CatalogItem y) {
      final na = x.name.isEmpty ? x.id : x.name;
      final nb = y.name.isEmpty ? y.id : y.name;
      return na.toLowerCase().compareTo(nb.toLowerCase());
    }

    final sa = stats[a.id];
    final sb = stats[b.id];
    final countA = sa?.runCount ?? 0;
    final countB = sb?.runCount ?? 0;
    final tierA = runResultTierRank(sa?.bestTier ?? RunResultTier.defeat);
    final tierB = runResultTierRank(sb?.bestTier ?? RunResultTier.defeat);
    final maxWinsA = sa?.maxWins ?? 0;
    final maxWinsB = sb?.maxWins ?? 0;

    final countCmp = ascending
        ? countA.compareTo(countB)
        : countB.compareTo(countA);
    if (countCmp != 0) return countCmp;

    final tierCmp = ascending
        ? tierA.compareTo(tierB)
        : tierB.compareTo(tierA);
    if (tierCmp != 0) return tierCmp;

    final maxWinsCmp = ascending
        ? maxWinsA.compareTo(maxWinsB)
        : maxWinsB.compareTo(maxWinsA);
    if (maxWinsCmp != 0) return maxWinsCmp;

    return nameCmp(a, b);
  }

  void _sortInPlace(
    List<CatalogItem> items,
    Map<String, ItemRunStats> stats,
    String sortKey,
    bool ascending,
  ) {
    int nameCmp(CatalogItem a, CatalogItem b) {
      final na = a.name.isEmpty ? a.id : a.name;
      final nb = b.name.isEmpty ? b.id : b.name;
      return na.toLowerCase().compareTo(nb.toLowerCase());
    }

    switch (sortKey) {
      case 'wins':
        items.sort((a, b) => _compareByWinsSort(a, b, stats, ascending));
      case 'alphabetical':
        items.sort(nameCmp);
        if (!ascending) {
          items.setAll(0, items.reversed);
        }
      default:
        items.sort(nameCmp);
        if (!ascending) {
          items.setAll(0, items.reversed);
        }
    }
  }

  List<CatalogItem> _applyPipeline({
    required List<CatalogItem> catalog,
    required Map<String, ItemRunStats> stats,
    required bool applyWinFilter,
    required Set<String> winFilterPassSet,
    required Map<String, CatalogItemSearchFields> fieldsById,
  }) {
    var list = _applySearch(catalog, _searchQuery, fieldsById);
    list = list
        .where(
          (item) => catalogItemMatchesAttributeFilters(
            item,
            heroTags: _selectedHeroTags,
            typeTags: _selectedTypeTags,
            rarities: _selectedRarities,
            sizes: _selectedSizes,
          ),
        )
        .toList(growable: false);

    if (_selectedHiddenTags.isNotEmpty) {
      list = list
          .where((item) {
            final have = item.hiddenTags.map((t) => t.trim()).toSet();
            for (final t in _selectedHiddenTags) {
              if (!have.contains(t.trim())) return false;
            }
            return true;
          })
          .toList(growable: false);
    }
    if (applyWinFilter) {
      list =
          list.where((item) => winFilterPassSet.contains(item.id)).toList(growable: false);
    }

    final sorted = List<CatalogItem>.from(list);

    final qLower = _searchQueryLower.trim();
    if (qLower.isNotEmpty) {
      // Relevance is used only for sorting when the user provides a query.
      // We keep the selected sort key as a deterministic tiebreaker.
      final relevanceScoreById = <String, int>{
        for (final item in sorted)
          item.id: computeCatalogItemRelevanceScore(
            fields: fieldsById[item.id] ?? buildCatalogItemSearchFields(item),
            queryLower: qLower,
          ),
      };

      int compareBySortKey(CatalogItem a, CatalogItem b) {
        int nameCmp(CatalogItem x, CatalogItem y) {
          final na = x.name.isEmpty ? x.id : x.name;
          final nb = y.name.isEmpty ? y.id : y.name;
          return na.toLowerCase().compareTo(nb.toLowerCase());
        }

        switch (_sortKey) {
          case 'wins': {
            return _compareByWinsSort(a, b, stats, _sortAscending);
          }
          case 'alphabetical': {
            final c = nameCmp(a, b);
            return _sortAscending ? c : -c;
          }
          default: {
            final c = nameCmp(a, b);
            return _sortAscending ? c : -c;
          }
        }
      }

      sorted.sort((a, b) {
        final ra = relevanceScoreById[a.id] ?? 0;
        final rb = relevanceScoreById[b.id] ?? 0;
        if (ra != rb) return rb.compareTo(ra); // higher relevance first
        return compareBySortKey(a, b);
      });
    } else {
      _sortInPlace(sorted, stats, _sortKey, _sortAscending);
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final runsRepo = createRunsRepository(
      isGuest: widget.isGuest,
      userId: widget.userId,
    );

    return StreamBuilder<List<RunRecord>>(
      stream: runsRepo.watchRuns(),
      builder: (context, runSnapshot) {
        final runsErrored = runSnapshot.hasError;
        final runs = runSnapshot.hasData
            ? runSnapshot.data!
            : const <RunRecord>[];
        final stats = runsErrored ? <String, ItemRunStats>{} : buildItemRunStatsMap(runs);
        return StreamBuilder<List<CatalogItem>>(
          stream: catalogRepository.watchActiveCatalogItems(),
          builder: (context, catSnapshot) {
            final horizontal = 16.0;
            final topPad = 16.0;
            final bottomPad = _catalogListPadding(context).bottom;

            final catalog = catSnapshot.data ?? const <CatalogItem>[];
            final fieldsById = <String, CatalogItemSearchFields>{
              for (final item in catalog) item.id: buildCatalogItemSearchFields(item),
            };

            // Attribute options derived from the loaded catalog.
            final attributeHeroes = catalog
                .map((e) => e.heroTag)
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            final tags = <String>{};
            for (final item in catalog) {
              tags.addAll(item.typeTags);
            }
            final attributeTypeTags = tags.toList()..sort();

            final attributeRarities = catalog
                .map((e) => e.startingRarity)
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            final attributeSizes = catalog
                .map(normalizedCatalogSize)
                .where((s) => s.isNotEmpty)
                .toSet()
                .toList()
              ..sort();

            // Build filtered results once per build; slivers virtualize row widgets.
            final effectiveRuns = runsErrored ? const <RunRecord>[] : runs;
            final effectiveStats = runsErrored ? <String, ItemRunStats>{} : stats;

            final winFilterActive = _winFilterEnabled && !runsErrored;
            final qualifiedRunCountByItemId = <String, int>{};
            final winFilterPassSet = <String>{};
            if (winFilterActive) {
              for (final r in effectiveRuns) {
                final qualifies =
                    r.wins >= _minWins && (!(_perfectOnly) || r.perfect);
                if (!qualifies) continue;
                for (final itemId in r.itemIds.toSet()) {
                  qualifiedRunCountByItemId.update(
                    itemId,
                    (c) => c + 1,
                    ifAbsent: () => 1,
                  );
                }
              }
              winFilterPassSet.addAll(qualifiedRunCountByItemId.keys);
            }

            final filtered = catSnapshot.hasData
                ? _applyPipeline(
                    catalog: catalog,
                    stats: effectiveStats,
                    applyWinFilter: winFilterActive,
                    winFilterPassSet: winFilterPassSet,
                    fieldsById: fieldsById,
                  )
                : const <CatalogItem>[];

            Widget sliverBox(Widget child) =>
                SliverToBoxAdapter(child: child);

            return CustomScrollView(
              controller: _catalogScrollController,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    topPad,
                    horizontal,
                    0,
                  ),
                  sliver: sliverBox(
                    SectionCard(
                      title: 'Search & filters',
                      subtitle: _catalogControlsExpanded
                          ? 'Search, sort, and filter.'
                          : 'Tap the tune icon to expand.',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: _hasActiveFilters ? _clearFilters : null,
                            child: const Text('Clear all'),
                          ),
                          IconButton(
                            tooltip: _catalogControlsExpanded
                                ? 'Hide search & filters'
                                : 'Show search & filters',
                            onPressed: () => setState(() {
                              _catalogControlsExpanded = !_catalogControlsExpanded;
                            }),
                            icon: Icon(
                              _catalogControlsExpanded
                                  ? Icons.expand_less
                                  : Icons.tune,
                            ),
                          ),
                        ],
                      ),
                      child: _catalogControlsExpanded
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextField(
                                  controller: _searchController,
                                  onChanged: (value) {
                                    _pendingSearchQuery = value;
                                    _searchDebounce?.cancel();
                                    _searchDebounce = Timer(
                                      const Duration(milliseconds: 180),
                                      () {
                                        if (!mounted) return;
                                        _applySearchQueryWithScrollRestore(
                                          _pendingSearchQuery,
                                        );
                                      },
                                    );
                                  },
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.search),
                                    labelText: 'Search items',
                                    hintText: 'Item name or keyword',
                                    suffixIcon: _searchQuery.isEmpty
                                        ? null
                                        : IconButton(
                                            onPressed: () {
                                              _searchDebounce?.cancel();
                                              _pendingSearchQuery = '';
                                              _searchController.clear();
                                              _applySearchQueryWithScrollRestore('');
                                            },
                                            icon: const Icon(Icons.clear),
                                          ),
                                  ),
                                ),
                                if (runsErrored) ...[
                                  const SizedBox(height: 12),
                                  Material(
                                    color: _surfaceInner,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Runs unavailable (${runSnapshot.error}). '
                                              'Stats and run-history filter need run data.',
                                              style: TextStyle(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                if (catSnapshot.hasError)
                                  _CatalogErrorState(
                                    onRetry: () => setState(() {}),
                                  )
                                else if (!catSnapshot.hasData)
                                  const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  )
                                else
                                  _CatalogAttributeFilters(
                                    attributeHeroes: attributeHeroes,
                                    attributeTypeTags: attributeTypeTags,
                                    attributeRarities: attributeRarities,
                                    attributeSizes: attributeSizes,
                                    selectedHeroTags: _selectedHeroTags,
                                    selectedTypeTags: _selectedTypeTags,
                                    selectedRarities: _selectedRarities,
                                    selectedSizes: _selectedSizes,
                                    sortKey: _sortKey,
                                    sortAscending: _sortAscending,
                                    onHeroSetChanged: (next) => setState(() {
                                      _selectedHeroTags
                                        ..clear()
                                        ..addAll(next);
                                    }),
                                    onTypeTagsSetChanged: (next) =>
                                        setState(() {
                                      _selectedTypeTags
                                        ..clear()
                                        ..addAll(next);
                                    }),
                                    onRaritySetChanged: (next) =>
                                        setState(() {
                                      _selectedRarities
                                        ..clear()
                                        ..addAll(next);
                                    }),
                                    onSizeSetChanged: (next) => setState(() {
                                      _selectedSizes
                                        ..clear()
                                        ..addAll(next);
                                    }),
                                    onSortKeyChanged: (v) =>
                                        setState(() => _sortKey = v),
                                    onSortDirectionToggle: () => setState(
                                      () => _sortAscending = !_sortAscending,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                Divider(
                                  height: 24,
                                  thickness: 1,
                                  color:
                                      _divider.withValues(alpha: 0.65),
                                ),
                                Text(
                                  'Run history',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Filter by run history'),
                                  subtitle: runsErrored
                                      ? Text(
                                          'Run data unavailable.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _muted,
                                          ),
                                        )
                                      : null,
                                  value: _winFilterEnabled && !runsErrored,
                                  onChanged: runsErrored
                                      ? null
                                      : (v) {
                                          setState(() {
                                            _winFilterEnabled = v;
                                            if (v) _minWins = 10;
                                            if (!v) _perfectOnly = false;
                                          });
                                        },
                                ),
                                if (_winFilterEnabled && !runsErrored) ...[
                                  const SizedBox(height: 4),
                                  LabeledSliderRow(
                                    label: 'Min wins',
                                    value: _minWins,
                                    min: 0,
                                    max: 10,
                                    divisions: 10,
                                    onChanged: (x) {
                                      setState(() {
                                        _minWins = x.round();
                                        if (_minWins < 10) _perfectOnly = false;
                                      });
                                    },
                                  ),
                                  if (_minWins == 10) ...[
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Perfect only'),
                                      subtitle: const Text(
                                        'Requires a perfect run (diamond).',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: _muted,
                                        ),
                                      ),
                                      value: _perfectOnly,
                                      onChanged: (v) => setState(
                                        () => _perfectOnly = v,
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),

                if (!_catalogControlsExpanded && runsErrored)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: sliverBox(
                      Material(
                        color: _surfaceInner,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Runs unavailable (${runSnapshot.error}). '
                                  'Stats and run-history filter need run data.',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.error,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  sliver: sliverBox(
                    Row(
                      children: [
                        Text(
                          'Catalog Items',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const Spacer(),
                        Text(
                          catSnapshot.hasData ? '${catalog.length} items' : 'Loading…',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: _muted),
                        ),
                      ],
                    ),
                  ),
                ),

                if (catSnapshot.hasError)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    sliver: sliverBox(
                      _CatalogErrorState(onRetry: () => setState(() {})),
                    ),
                  )
                else if (!catSnapshot.hasData)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    sliver: sliverBox(
                      const Center(child: CircularProgressIndicator()),
                    ),
                  )
                else if (catalog.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: sliverBox(
                      const _CatalogEmptyState(message: 'No catalog items.'),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: sliverBox(
                      _CatalogEmptyState(
                        message: _searchQuery.trim().isEmpty
                            ? 'No catalog items match your filters.'
                            : "No results for '${_searchQuery.trim()}'.",
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filtered[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _CatalogItemTile(
                              key: ValueKey('catalog_item_${item.id}_$index'),
                              item: item,
                              stats: effectiveStats[item.id],
                              runsDataAvailable: !runsErrored,
                              qualifiedRunCount: winFilterActive
                                  ? (qualifiedRunCountByItemId[item.id] ?? 0)
                                  : (effectiveStats[item.id]?.runCount ?? 0),
                              winFilterActive: winFilterActive,
                            ),
                          );
                        },
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

}

class _CatalogAttributeFilters extends StatelessWidget {
  const _CatalogAttributeFilters({
    required this.attributeHeroes,
    required this.attributeTypeTags,
    required this.attributeRarities,
    required this.attributeSizes,
    required this.selectedHeroTags,
    required this.selectedTypeTags,
    required this.selectedRarities,
    required this.selectedSizes,
    required this.sortKey,
    required this.sortAscending,
    required this.onHeroSetChanged,
    required this.onTypeTagsSetChanged,
    required this.onRaritySetChanged,
    required this.onSizeSetChanged,
    required this.onSortKeyChanged,
    required this.onSortDirectionToggle,
  });

  final List<String> attributeHeroes;
  final List<String> attributeTypeTags;
  final List<String> attributeRarities;
  final List<String> attributeSizes;
  final Set<String> selectedHeroTags;
  final Set<String> selectedTypeTags;
  final Set<String> selectedRarities;
  final Set<String> selectedSizes;
  final String sortKey;
  final bool sortAscending;
  final void Function(Set<String> value) onHeroSetChanged;
  final void Function(Set<String> value) onTypeTagsSetChanged;
  final void Function(Set<String> value) onRaritySetChanged;
  final void Function(Set<String> value) onSizeSetChanged;
  final void Function(String value) onSortKeyChanged;
  final VoidCallback onSortDirectionToggle;

  @override
  Widget build(BuildContext context) {
    final heroes = attributeHeroes;
    final tagList = attributeTypeTags;
    final rarities = attributeRarities;
    final sizes = attributeSizes;

    final attributeSelections = selectedHeroTags.length +
        selectedTypeTags.length +
        selectedRarities.length +
        selectedSizes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'Ordering',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFFEED9BA),
                  ),
            ),
            const Spacer(),
            _OrderingSliderToggle(
              sortKey: sortKey,
              onChanged: onSortKeyChanged,
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: sortAscending ? 'Ascending' : 'Descending',
              onPressed: onSortDirectionToggle,
              icon: Icon(
                sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 18,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            initiallyExpanded: false,
            title: Text(
              'Attribute filters',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            subtitle: Text(
              attributeSelections == 0
                  ? 'Hero, tags, rarity, size'
                  : '$attributeSelections selected',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFC3B5A0),
                height: 1.35,
              ),
            ),
            childrenPadding: const EdgeInsets.only(top: 8, bottom: 8),
            children: [
              Row(
                children: [
                  Expanded(
                    child: _CompactFilterButton(
                      label: 'Hero',
                      count: selectedHeroTags.length,
                      enabled: heroes.isNotEmpty,
                      onTap: () async {
                        await _showCatalogMultiSelectSheet(
                          context: context,
                          title: 'Hero',
                          options: heroes,
                          selected: selectedHeroTags,
                          onCommit: onHeroSetChanged,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactFilterButton(
                      label: 'Tags',
                      count: selectedTypeTags.length,
                      enabled: tagList.isNotEmpty,
                      onTap: () async {
                        await _showCatalogMultiSelectSheet(
                          context: context,
                          title: 'Type tags (all must match)',
                          options: tagList,
                          selected: selectedTypeTags,
                          onCommit: onTypeTagsSetChanged,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _CompactFilterButton(
                      label: 'Rarity',
                      count: selectedRarities.length,
                      enabled: rarities.isNotEmpty,
                      onTap: () async {
                        await _showCatalogMultiSelectSheet(
                          context: context,
                          title: 'Rarity',
                          options: rarities,
                          selected: selectedRarities,
                          onCommit: onRaritySetChanged,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CompactFilterButton(
                      label: 'Size',
                      count: selectedSizes.length,
                      enabled: sizes.isNotEmpty,
                      onTap: () async {
                        await _showCatalogMultiSelectSheet(
                          context: context,
                          title: 'Size',
                          options: sizes,
                          selected: selectedSizes,
                          onCommit: onSizeSetChanged,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _showCatalogMultiSelectSheet({
  required BuildContext context,
  required String title,
  required List<String> options,
  required Set<String> selected,
  required void Function(Set<String> value) onCommit,
}) async {
  final latest = ValueNotifier<Set<String>>(Set<String>.from(selected));
  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _CatalogMultiSelectSheet(
        title: title,
        options: options,
        selectionNotifier: latest,
      ),
    );
    if (!context.mounted) return;
    onCommit(Set<String>.from(latest.value));
  } finally {
    latest.dispose();
  }
}

class _CompactFilterButton extends StatelessWidget {
  const _CompactFilterButton({
    required this.label,
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelText = count > 0 ? '$label ($count)' : label;
    return OutlinedButton(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              labelText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: enabled ? null : Theme.of(context).disabledColor,
          ),
        ],
      ),
    );
  }
}

class _OrderingSliderToggle extends StatelessWidget {
  const _OrderingSliderToggle({
    required this.sortKey,
    required this.onChanged,
  });

  final String sortKey;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedColor = Theme.of(context).colorScheme.primary;
    const surface = Color(0xFF120A0B);
    const border = Color(0xFF62401F);
    const textMuted = Color(0xFFE2B569);
    const onSelected = Color(0xFF1A1106);
    final isAlpha = sortKey == 'alphabetical';

    return Container(
      height: 44,
      width: 170,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            alignment: isAlpha ? Alignment.centerLeft : Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged('alphabetical'),
                  child: Center(
                    child: Text(
                      'A-Z',
                      style: TextStyle(
                        color: isAlpha ? onSelected : textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged('wins'),
                  child: Center(
                    child: Text(
                      'Wins',
                      style: TextStyle(
                        color: isAlpha ? textMuted : onSelected,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogMultiSelectSheet extends StatefulWidget {
  const _CatalogMultiSelectSheet({
    required this.title,
    required this.options,
    required this.selectionNotifier,
  });

  final String title;
  final List<String> options;
  final ValueNotifier<Set<String>> selectionNotifier;

  @override
  State<_CatalogMultiSelectSheet> createState() => _CatalogMultiSelectSheetState();
}

class _CatalogMultiSelectSheetState extends State<_CatalogMultiSelectSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> get _filteredOptions {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return widget.options;
    return widget.options
        .where((o) => o.toLowerCase().contains(q))
        .toList(growable: false);
  }

  void _toggle(String opt, bool? checked) {
    final next = Set<String>.from(widget.selectionNotifier.value);
    if (checked ?? false) {
      next.add(opt);
    } else {
      next.remove(opt);
    }
    widget.selectionNotifier.value = next;
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.62;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                            ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        widget.selectionNotifier.value = <String>{};
                      },
                      child: const Text('Clear'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: const InputDecoration(
                    hintText: 'Search list…',
                    prefixIcon: Icon(Icons.search, size: 22),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ValueListenableBuilder<Set<String>>(
                  valueListenable: widget.selectionNotifier,
                  builder: (context, selectedSet, _) {
                    if (_filteredOptions.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'No matches',
                            style: TextStyle(color: Color(0xFFC3B5A0)),
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: _filteredOptions.length,
                      itemBuilder: (context, i) {
                        final opt = _filteredOptions[i];
                        return CheckboxListTile(
                          dense: true,
                          title: Text(
                            opt,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          value: selectedSet.contains(opt),
                          onChanged: (checked) => _toggle(opt, checked),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogItemTile extends StatelessWidget {
  const _CatalogItemTile({
    super.key,
    required this.item,
    this.stats,
    required this.runsDataAvailable,
    required this.qualifiedRunCount,
    required this.winFilterActive,
  });

  final CatalogItem item;
  final ItemRunStats? stats;
  /// False when run history could not be loaded (omit per-row run counts).
  final bool runsDataAvailable;
  /// Runs matching current win-history criteria (or all runs with item when filter is off).
  final int qualifiedRunCount;
  final bool winFilterActive;

  static const _surfaceInner = Color(0xFF241516);
  static const _border = Color(0xFF5B3A1F);

  @override
  Widget build(BuildContext context) {
    final runCount = stats?.runCount ?? 0;
    final bestTier = stats?.bestTier ?? RunResultTier.defeat;
    final maxWins = stats?.maxWins ?? 0;
    final thumbSlotHeight = 52.0;
    final slotCount = switch (item.size.trim().toLowerCase()) {
      'small' => 1,
      'medium' => 2,
      'large' => 3,
      _ => 2,
    };
    final thumbSlotWidth = (thumbSlotHeight / 2) * slotCount;
    final tierForStyle =
        runCount == 0 ? RunResultTier.defeat : bestTier;
    final tierStyle = RunTierStyle.forTier(tierForStyle);
    final tierTitle = runCount == 0
        ? 'No runs yet'
        : runResultTierShortLabel(bestTier);
    final tags = item.typeTags.isEmpty ? 'No tags' : item.typeTags.join(', ');
    final displayName = item.name.isEmpty ? item.id : item.name;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CatalogItemDetailPage(
                  item: item,
                  stats: stats,
                  runsDataAvailable: runsDataAvailable,
                  qualifiedRunCount: qualifiedRunCount,
                  winFilterActive: winFilterActive,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _surfaceInner,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: tierStyle.accentBar),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: thumbSlotWidth,
                                height: thumbSlotHeight,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(color: tierStyle.iconBackground),
                                      if (item.imageThumbUrl != null)
                                        CachedNetworkImage(
                                          imageUrl: item.imageThumbUrl!,
                                          cacheKey:
                                              'thumb_v3_${item.id}_${item.imageThumbUrl!.hashCode}',
                                          httpHeaders: const {
                                            'User-Agent':
                                                'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                                          },
                                          fit: BoxFit.contain,
                                          alignment: Alignment.center,
                                          placeholder: (_, __) =>
                                              const SizedBox.shrink(),
                                          errorWidget: (_, __, ___) =>
                                              const SizedBox.shrink(),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            displayName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: tierStyle.labelColor,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: tierStyle.iconBackground,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          alignment: Alignment.center,
                                          child: tierStyle.buildIcon(size: 16),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      tierTitle,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: const Color(0xFFC3B5A0),
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _CatalogItemMetaCard(
                            heroLine: '${item.heroTag.isEmpty ? 'Unknown hero' : item.heroTag} · '
                                '${item.startingRarity.isEmpty ? 'Unknown rarity' : item.startingRarity} · '
                                '${normalizedCatalogSize(item).isEmpty ? 'Unknown size' : normalizedCatalogSize(item)}',
                            bestWinsText:
                                runCount > 0 ? 'Best $maxWins wins' : null,
                            runCountText: runsDataAvailable
                                ? '$qualifiedRunCount ${qualifiedRunCount == 1 ? 'run' : 'runs'}'
                                : null,
                            tooltip: !runsDataAvailable
                                ? null
                                : winFilterActive
                                    ? 'Number of saved runs that match your Run history filter above.'
                                    : 'Times this item appeared in a saved run.',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tags,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFD0C0A8),
                              height: 1.35,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Hero / rarity / size on the first line; best wins and run count on a second line.
class _CatalogItemMetaCard extends StatelessWidget {
  const _CatalogItemMetaCard({
    required this.heroLine,
    this.bestWinsText,
    this.runCountText,
    this.tooltip,
  });

  final String heroLine;
  final String? bestWinsText;
  final String? runCountText;
  final String? tooltip;

  static const _primaryStyle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );
  static const _statsStyle = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: Color(0xFFC3B5A0),
    height: 1.35,
  );

  @override
  Widget build(BuildContext context) {
    final hasStats =
        (bestWinsText != null && bestWinsText!.isNotEmpty) ||
            (runCountText != null && runCountText!.isNotEmpty);

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF120A0B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF62401F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.stacked_line_chart,
                size: 16,
                color: Color(0xFFE2B569),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  heroLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _primaryStyle,
                ),
              ),
            ],
          ),
          if (hasStats) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (bestWinsText != null && bestWinsText!.isNotEmpty)
                    Text(
                      bestWinsText!,
                      style: _statsStyle,
                    ),
                  if (runCountText != null && runCountText!.isNotEmpty)
                    Text(
                      runCountText!,
                      style: _statsStyle,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );

    if (tooltip == null || tooltip!.isEmpty) return card;
    return Tooltip(
      message: tooltip!,
      child: card,
    );
  }
}

class _CatalogErrorState extends StatelessWidget {
  const _CatalogErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Could not load the catalog. Check your connection and try again.',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

class _CatalogEmptyState extends StatelessWidget {
  const _CatalogEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
        height: 1.4,
      ),
    );
  }
}
