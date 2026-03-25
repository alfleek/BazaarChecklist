import 'package:flutter/material.dart';
import 'package:mobile/features/catalog/catalog_item.dart';

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

class _CatalogItemPickerBody extends StatefulWidget {
  const _CatalogItemPickerBody({required this.items});

  final List<CatalogItem> items;

  @override
  State<_CatalogItemPickerBody> createState() => _CatalogItemPickerBodyState();
}

class _CatalogItemPickerBodyState extends State<_CatalogItemPickerBody> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CatalogItem> get _filtered {
    final available = widget.items;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return available;
    return available.where((i) {
      if (i.name.toLowerCase().contains(q)) return true;
      if (i.heroTag.toLowerCase().contains(q)) return true;
      return i.typeTags.any((t) => t.toLowerCase().contains(q));
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
              Expanded(
                child: _filtered.isEmpty
                    ? Center(
                        child: Text(
                          widget.items.isEmpty
                              ? 'No catalog items loaded.'
                              : 'No matching items.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = _filtered[index];
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
