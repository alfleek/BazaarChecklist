import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
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
  int _reloadKey = 0;
  bool _catalogPrefillApplyScheduled = false;
  bool _catalogControlsExpanded = true;

  final Set<String> _selectedHeroTags = {};
  final Set<String> _selectedTypeTags = {};
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
      }
      if (args.collapseCatalogControls) {
        _catalogControlsExpanded = false;
      }
    });
    sessionController.clearPendingCatalogPrefill();
  }

  @override
  void dispose() {
    sessionController.removeListener(_onSessionChangedForCatalogPrefill);
    _searchController.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters {
    return _selectedHeroTags.isNotEmpty ||
        _selectedTypeTags.isNotEmpty ||
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
      _selectedRarities.clear();
      _selectedSizes.clear();
      _winFilterEnabled = false;
      _minWins = 10;
      _perfectOnly = false;
      _sortKey = 'alphabetical';
      _sortAscending = true;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  List<CatalogItem> _applySearch(
    List<CatalogItem> items,
    String query,
  ) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return items;
    return items.where((item) {
      final matchesName = item.name.toLowerCase().contains(trimmed);
      final matchesHero = item.heroTag.toLowerCase().contains(trimmed);
      final matchesTag = item.typeTags.any(
        (tag) => tag.toLowerCase().contains(trimmed),
      );
      return matchesName || matchesHero || matchesTag;
    }).toList(growable: false);
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
        items.sort((a, b) {
          final ca = stats[a.id]?.runCount ?? 0;
          final cb = stats[b.id]?.runCount ?? 0;
          final c = ascending ? ca.compareTo(cb) : cb.compareTo(ca);
          if (c != 0) return c;
          return nameCmp(a, b);
        });
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
    required List<RunRecord> runs,
    required Map<String, ItemRunStats> stats,
    required bool applyWinFilter,
  }) {
    var list = _applySearch(catalog, _searchQuery);
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
    if (applyWinFilter) {
      list = list
          .where(
            (item) => itemPassesWinHistoryFilter(
              itemId: item.id,
              runs: runs,
              minWins: _minWins,
              perfectOnly: _perfectOnly,
            ),
          )
          .toList(growable: false);
    }
    final sorted = List<CatalogItem>.from(list);
    _sortInPlace(sorted, stats, _sortKey, _sortAscending);
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
          key: ValueKey(_reloadKey),
          stream: catalogRepository.watchActiveCatalogItems(),
          builder: (context, catSnapshot) {
            return ListView(
              padding: _catalogListPadding(context),
              children: [
                SectionCard(
                  title: 'Search & filters',
                  subtitle: _catalogControlsExpanded
                      ? 'Search, sort, and filter.'
                      : 'Tap the tune icon to expand.',
                  trailing: IconButton(
                    tooltip: _catalogControlsExpanded
                        ? 'Hide search & filters'
                        : 'Show search & filters',
                    onPressed: () => setState(() {
                      _catalogControlsExpanded = !_catalogControlsExpanded;
                    }),
                    icon: Icon(
                      _catalogControlsExpanded ? Icons.expand_less : Icons.tune,
                    ),
                  ),
                  child: _catalogControlsExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _searchQuery = value),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                labelText: 'Search items',
                                hintText: 'Item name or keyword',
                                suffixIcon: _searchQuery.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchQuery = '');
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
                            ],
                            const SizedBox(height: 16),
                            if (catSnapshot.hasData)
                              _CatalogAttributeFilters(
                                catalog: catSnapshot.data!,
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
                                onTypeTagsSetChanged: (next) => setState(() {
                                  _selectedTypeTags
                                    ..clear()
                                    ..addAll(next);
                                }),
                                onRaritySetChanged: (next) => setState(() {
                                  _selectedRarities
                                    ..clear()
                                    ..addAll(next);
                                }),
                                onSizeSetChanged: (next) => setState(() {
                                  _selectedSizes
                                    ..clear()
                                    ..addAll(next);
                                }),
                                onSortKeyChanged: (v) => setState(() => _sortKey = v),
                                onSortDirectionToggle: () =>
                                    setState(() => _sortAscending = !_sortAscending),
                                onClearFilters: _hasActiveFilters ? _clearFilters : null,
                              )
                            else if (catSnapshot.hasError)
                              _CatalogErrorState(
                                onRetry: () => setState(() => _reloadKey++),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            const SizedBox(height: 8),
                            Divider(height: 24, thickness: 1, color: _divider.withValues(alpha: 0.65)),
                            Text(
                              'Run history',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
                                      style: TextStyle(fontSize: 12, color: _muted),
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
                                    style: TextStyle(fontSize: 12, color: _muted),
                                  ),
                                  value: _perfectOnly,
                                  onChanged: (v) =>
                                      setState(() => _perfectOnly = v),
                                ),
                              ],
                            ],
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                if (!_catalogControlsExpanded && runsErrored)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                  child: Row(
                    children: [
                      Text(
                        'Catalog Items',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const Spacer(),
                      Text(
                        catSnapshot.hasData ? '${catSnapshot.data!.length} items' : 'Loading…',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _muted,
                            ),
                      ),
                    ],
                  ),
                ),
                _buildCatalogBody(
                  context,
                  catSnapshot: catSnapshot,
                  runs: runs,
                  stats: stats,
                  runsErrored: runsErrored,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCatalogBody(
    BuildContext context, {
    required AsyncSnapshot<List<CatalogItem>> catSnapshot,
    required List<RunRecord> runs,
    required Map<String, ItemRunStats> stats,
    required bool runsErrored,
  }) {
    if (catSnapshot.hasError) {
      return _CatalogErrorState(
        onRetry: () => setState(() => _reloadKey++),
      );
    }
    if (!catSnapshot.hasData) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final catalog = catSnapshot.data ?? const <CatalogItem>[];
    if (catalog.isEmpty) {
      return const _CatalogEmptyState(
        message:
            'No catalog items.',
      );
    }

    final effectiveRuns = runsErrored ? const <RunRecord>[] : runs;
    final effectiveStats = runsErrored ? <String, ItemRunStats>{} : stats;

    final filtered = _applyPipeline(
      catalog: catalog,
      runs: effectiveRuns,
      stats: effectiveStats,
      applyWinFilter: _winFilterEnabled && !runsErrored,
    );

    if (filtered.isEmpty) {
      return _CatalogEmptyState(
        message: _hasActiveFilters
            ? 'No items match your search or filters.'
            : 'No catalog items match your search.',
      );
    }

    final minWinsForCount = _winFilterEnabled && !runsErrored ? _minWins : 0;
    final perfectForCount = _winFilterEnabled && !runsErrored && _perfectOnly;

    return Column(
      children: filtered
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CatalogItemTile(
                item: item,
                stats: effectiveStats[item.id],
                runsDataAvailable: !runsErrored,
                qualifiedRunCount: runsErrored
                    ? 0
                    : countRunsForItemWithWinCriteria(
                        itemId: item.id,
                        runs: effectiveRuns,
                        minWins: minWinsForCount,
                        perfectOnly: perfectForCount,
                      ),
                winFilterActive: _winFilterEnabled && !runsErrored,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _CatalogAttributeFilters extends StatelessWidget {
  const _CatalogAttributeFilters({
    required this.catalog,
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
    this.onClearFilters,
  });

  final List<CatalogItem> catalog;
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
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    final heroes = catalog.map((e) => e.heroTag).where((s) => s.isNotEmpty).toSet().toList()
      ..sort();
    final tags = <String>{};
    for (final item in catalog) {
      tags.addAll(item.typeTags);
    }
    final tagList = tags.toList()..sort();
    final rarities = catalog.map((e) => e.startingRarity).where((s) => s.isNotEmpty).toSet().toList()
      ..sort();
    final sizes = catalog.map(normalizedCatalogSize).where((s) => s.isNotEmpty).toSet().toList()
      ..sort();

    final attributeSelections = selectedHeroTags.length +
        selectedTypeTags.length +
        selectedRarities.length +
        selectedSizes.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onClearFilters != null) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear all'),
            ),
          ),
          const SizedBox(height: 8),
        ],
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
    final tierForStyle =
        runCount == 0 ? RunResultTier.defeat : bestTier;
    final tierStyle = RunTierStyle.forTier(tierForStyle);
    final tierTitle = runCount == 0
        ? 'No runs yet'
        : runResultTierShortLabel(bestTier);
    final tags = item.typeTags.isEmpty ? 'No tags' : item.typeTags.join(', ');

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: tierStyle.iconBackground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: tierStyle.buildIcon(size: 22),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name.isEmpty ? item.id : item.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: tierStyle.labelColor,
                                      ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tierTitle,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
