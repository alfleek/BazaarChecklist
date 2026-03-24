import 'package:flutter/material.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _reloadKey = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Catalog Search',
          subtitle: 'Search by item name and keywords.',
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Search items',
              hintText: 'Type an item name...',
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
        ),
        SectionCard(
          title: 'Catalog Filters',
          subtitle: 'Hero, type tags, rarity, size, and won status.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const [
                  FilterChip(label: Text('Hero: Vanessa'), onSelected: null),
                  FilterChip(label: Text('Tag: Burn'), onSelected: null),
                  FilterChip(label: Text('Rarity: Rare'), onSelected: null),
                  FilterChip(label: Text('Size: Medium'), onSelected: null),
                  FilterChip(label: Text('Won: Not Yet'), onSelected: null),
                ],
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: 'alphabetical',
                items: const [
                  DropdownMenuItem(
                    value: 'alphabetical',
                    child: Text('Sort: Alphabetical'),
                  ),
                  DropdownMenuItem(
                    value: 'mostWon',
                    child: Text('Sort: Most won with'),
                  ),
                  DropdownMenuItem(
                    value: 'leastWon',
                    child: Text('Sort: Least won with'),
                  ),
                ],
                onChanged: (_) {},
                decoration: const InputDecoration(labelText: 'Ordering'),
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Catalog Items',
          subtitle: 'Live data from Firestore (`catalog_items`).',
          child: StreamBuilder<List<CatalogItem>>(
            key: ValueKey(_reloadKey),
            stream: catalogRepository.watchActiveCatalogItems(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return _CatalogErrorState(
                  onRetry: () => setState(() => _reloadKey++),
                );
              }

              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final filteredItems = _applySearch(
                snapshot.data ?? const <CatalogItem>[],
                _searchQuery,
              );
              if (filteredItems.isEmpty) {
                return _CatalogEmptyState(hasSearchQuery: _searchQuery.isNotEmpty);
              }

              return Column(
                children: filteredItems
                    .map((item) => _CatalogItemTile(item: item))
                    .toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CatalogItemTile extends StatelessWidget {
  const _CatalogItemTile({required this.item});

  final CatalogItem item;

  @override
  Widget build(BuildContext context) {
    final tags = item.typeTags.isEmpty ? 'No tags' : item.typeTags.join(', ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF241516),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5B3A1F)),
        ),
        child: ListTile(
          title: Text(item.name.isEmpty ? item.id : item.name),
          subtitle: Text(
            '${item.heroTag} - ${item.startingRarity} - size ${item.size} \n$tags',
            style: const TextStyle(color: Color(0xFFD0C0A8)),
          ),
          isThreeLine: true,
        ),
      ),
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
          'Unable to load catalog items. Check your Firestore rules and network connection.',
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
  const _CatalogEmptyState({required this.hasSearchQuery});

  final bool hasSearchQuery;

  @override
  Widget build(BuildContext context) {
    if (hasSearchQuery) {
      return const Text('No catalog items match your search.');
    }
    return const Text(
      'No active catalog items found. Add documents in Firestore under catalog_items.',
    );
  }
}
