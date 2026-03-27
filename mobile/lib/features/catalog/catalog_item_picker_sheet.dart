import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';
import 'package:mobile/features/catalog/catalog_search_utils.dart';

/// Searchable list of catalog items for picking one item (duplicates allowed).
Future<CatalogItem?> showCatalogItemPicker({
  required BuildContext context,
  required List<CatalogItem> items,
}) {
  return showModalBottomSheet<CatalogItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1B1112),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return _CatalogItemPickerBody(items: items);
    },
  );
}

Future<CatalogItem?> showCatalogItemPickerPaged({
  required BuildContext context,
  int pageSize = 50,
}) {
  return showModalBottomSheet<CatalogItem>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1B1112),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const _StreamCatalogItemPickerBody(),
  );
}

class _CatalogItemPickerBody extends StatefulWidget {
  const _CatalogItemPickerBody({required this.items});

  final List<CatalogItem> items;

  @override
  State<_CatalogItemPickerBody> createState() => _CatalogItemPickerBodyState();
}

class _StreamCatalogItemPickerBody extends StatefulWidget {
  const _StreamCatalogItemPickerBody();

  @override
  State<_StreamCatalogItemPickerBody> createState() =>
      _StreamCatalogItemPickerBodyState();
}

class _StreamCatalogItemPickerBodyState extends State<_StreamCatalogItemPickerBody> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';
  String _queryNorm = '';
  double _browseScrollOffset = 0;
  double _searchScrollOffset = 0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_rememberScrollOffsetByMode);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.removeListener(_rememberScrollOffsetByMode);
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _rememberScrollOffsetByMode() {
    if (!_scroll.hasClients) return;
    final offset = _scroll.offset;
    if (_queryNorm.isEmpty) {
      _browseScrollOffset = offset;
    } else {
      _searchScrollOffset = offset;
    }
  }

  void _applyQueryWithScrollRestore(String nextQuery) {
    final nextNorm = normalizeCatalogSearchQuery(nextQuery);
    final wasSearch = _queryNorm.isNotEmpty;
    final isSearch = nextNorm.isNotEmpty;

    _rememberScrollOffsetByMode();
    setState(() {
      _query = nextQuery;
      _queryNorm = nextNorm;
    });

    if (wasSearch == isSearch) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final target = isSearch ? _searchScrollOffset : _browseScrollOffset;
      final pos = _scroll.position;
      final clamped = target.clamp(0, pos.maxScrollExtent).toDouble();
      if ((_scroll.offset - clamped).abs() < 1) return;
      _scroll.jumpTo(clamped);
    });
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      _applyQueryWithScrollRestore(v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.of(context).size.height * 0.72;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add item from catalog',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: 'Search by name or tag',
                    hintText: 'Type to search…',
                    suffixIcon: _query.trim().isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _debounce?.cancel();
                              _search.clear();
                              _applyQueryWithScrollRestore('');
                            },
                            icon: const Icon(Icons.clear),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: StreamBuilder<List<CatalogItem>>(
                  stream: catalogRepository.watchActiveCatalogItems(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load catalog: ${snapshot.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final items = snapshot.data ?? const <CatalogItem>[];
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'No catalog items loaded.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      );
                    }

                    final fieldsById = <String, CatalogItemSearchFields>{
                      for (final i in items) i.id: buildCatalogItemSearchFields(i),
                    };

                    final List<CatalogItem> filtered = _queryNorm.isEmpty
                        ? items
                        : items
                            .where((i) => (fieldsById[i.id]?.matchesLower(_queryNorm) ?? false))
                            .toList(growable: false);

                    final ranked = _queryNorm.isEmpty
                        ? filtered
                        : (List<CatalogItem>.from(filtered)
                          ..sort((a, b) {
                            final ra = computeCatalogItemRelevanceScore(
                              fields: fieldsById[a.id] ?? buildCatalogItemSearchFields(a),
                              queryLower: _queryNorm,
                            );
                            final rb = computeCatalogItemRelevanceScore(
                              fields: fieldsById[b.id] ?? buildCatalogItemSearchFields(b),
                              queryLower: _queryNorm,
                            );
                            if (ra != rb) return rb.compareTo(ra);
                            final na = a.name.isEmpty ? a.id : a.name;
                            final nb = b.name.isEmpty ? b.id : b.name;
                            return na.toLowerCase().compareTo(nb.toLowerCase());
                          }));

                    if (ranked.isEmpty) {
                      return Center(
                        child: Text(
                          _query.trim().isEmpty
                              ? 'No items.'
                              : "No results for '${_query.trim()}'.",
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: ranked.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = ranked[index];
                        final displayName = item.name.isEmpty ? item.id : item.name;
                        final subtitle = [
                          if (item.heroTag.isNotEmpty) item.heroTag,
                          item.startingRarity,
                          item.size,
                        ].where((s) => s.isNotEmpty).join(' · ');

                        return Material(
                          color: const Color(0xFF241516),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(item),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (subtitle.isNotEmpty)
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        color: Color(0xFFD0C0A8),
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
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

class _CatalogItemPickerBodyState extends State<_CatalogItemPickerBody> {
  final _search = TextEditingController();
  String _query = '';
  final Map<String, CatalogItemSearchFields> _searchFieldsById = {};

  void _rebuildSearchFields() {
    _searchFieldsById
      ..clear()
      ..addAll({
        for (final i in widget.items) i.id: buildCatalogItemSearchFields(i),
      });
  }

  @override
  void initState() {
    super.initState();
    _rebuildSearchFields();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CatalogItemPickerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild when the catalog list changes (the parent is allowed to pass a new list).
    _rebuildSearchFields();
  }

  List<CatalogItem> get _filtered {
    final available = widget.items;
    final q = normalizeCatalogSearchQuery(_query);
    if (q.isEmpty) return available;
    return available.where((i) {
      final f = _searchFieldsById[i.id] ?? buildCatalogItemSearchFields(i);
      return f.matchesLower(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Add item from catalog',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search by name or tag',
                    hintText: 'Type to filter…',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Builder(
                builder: (_) {
                  final rankedBase = _filtered;
                  final qLower = normalizeCatalogSearchQuery(_query);
                  final ranked = qLower.isEmpty
                      ? rankedBase
                      : List<CatalogItem>.from(rankedBase)
                        ..sort((a, b) {
                          final ra = computeCatalogItemRelevanceScore(
                            fields: buildCatalogItemSearchFields(a),
                            queryLower: qLower,
                          );
                          final rb = computeCatalogItemRelevanceScore(
                            fields: buildCatalogItemSearchFields(b),
                            queryLower: qLower,
                          );
                          if (ra != rb) return rb.compareTo(ra);

                          final na = a.name.isEmpty ? a.id : a.name;
                          final nb = b.name.isEmpty ? b.id : b.name;
                          return na.toLowerCase().compareTo(nb.toLowerCase());
                        });
                  return Expanded(
                    child: ranked.isEmpty
                        ? Center(
                            child: Text(
                              widget.items.isEmpty
                                  ? 'No catalog items loaded.'
                                  : 'No matching items.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            itemCount: ranked.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final item = ranked[index];
                              final subtitle = [
                                if (item.heroTag.isNotEmpty) item.heroTag,
                                item.startingRarity,
                                item.size,
                              ].where((s) => s.isNotEmpty).join(' · ');
                              return Material(
                                color: const Color(0xFF241516),
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () => Navigator.of(context).pop(item),
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name.isEmpty ? item.id : item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (subtitle.isNotEmpty)
                                          Text(
                                            subtitle,
                                            style: const TextStyle(
                                              color: Color(0xFFD0C0A8),
                                              fontSize: 13,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
