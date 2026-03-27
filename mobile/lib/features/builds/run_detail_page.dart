import 'package:flutter/material.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_detail_page.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/run_result_tier.dart';
import 'package:mobile/features/runs/run_tier_visual.dart';

class RunDetailPage extends StatefulWidget {
  const RunDetailPage({super.key, required this.run, required this.allRuns});

  final RunRecord run;
  final List<RunRecord> allRuns;

  @override
  State<RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends State<RunDetailPage> {
  late final Future<List<CatalogItem>> _itemsFuture = _loadRunItems();
  late final Map<String, ItemRunStats> _statsByItem = buildItemRunStatsMap(
    widget.allRuns,
  );

  Future<List<CatalogItem>> _loadRunItems() async {
    final cache = <String, CatalogItem>{};
    final ordered = <CatalogItem>[];
    for (final itemId in widget.run.itemIds) {
      final cached = cache[itemId];
      if (cached != null) {
        ordered.add(cached);
        continue;
      }
      final fetched = await catalogRepository.fetchCatalogItemById(itemId);
      final item = fetched ?? CatalogItem.unknown(itemId);
      cache[itemId] = item;
      ordered.add(item);
    }
    return ordered;
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    final y = local.year;
    final m = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$day · $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final tierStyle = RunTierStyle.forTier(run.resultTier);
    final modeLabel = run.mode == 'ranked' ? 'Ranked' : 'Normal';

    return Scaffold(
      backgroundColor: const Color(0xFF120A0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF120A0B),
        foregroundColor: const Color(0xFFF3E4CC),
        elevation: 0,
        title: const Text('Run details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1011),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF5B3A1F)),
            ),
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
                            runResultTierLabel(run.resultTier),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: tierStyle.labelColor,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(run.createdAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFFC3B5A0),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _RunChip(icon: Icons.person_outline, text: run.heroId),
                    _RunChip(icon: Icons.leaderboard, text: modeLabel),
                    _RunChip(icon: Icons.stacked_line_chart, text: '${run.wins} wins'),
                    if (run.perfect)
                      const _RunChip(icon: Icons.diamond, text: 'Perfect'),
                    _RunChip(
                      icon: Icons.inventory_2_outlined,
                      text: '${run.itemIds.length} items',
                    ),
                  ],
                ),
                if (run.notes.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    run.notes.trim(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFD0C0A8),
                          height: 1.35,
                        ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Items in this run',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFF3E4CC),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<CatalogItem>>(
            future: _itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1011),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF5B3A1F)),
                  ),
                  child: Text(
                    'Could not load items: ${snapshot.error}',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1011),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF5B3A1F)),
                  ),
                  child: const Text(
                    'No items were saved with this run.',
                    style: TextStyle(color: Color(0xFFC3B5A0)),
                  ),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _RunItemTile(
                      item: items[i],
                      stats: _statsByItem[items[i].id],
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RunItemTile extends StatelessWidget {
  const _RunItemTile({required this.item, this.stats});

  final CatalogItem item;
  final ItemRunStats? stats;

  @override
  Widget build(BuildContext context) {
    final title = item.name.isEmpty ? item.id : item.name;
    final subtitle = [
      if (item.heroTag.isNotEmpty) item.heroTag,
      if (item.startingRarity.isNotEmpty) item.startingRarity,
      if (item.size.isNotEmpty) item.size,
    ].join(' · ');
    return Material(
      color: const Color(0xFF241516),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => CatalogItemDetailPage(
                item: item,
                stats: stats,
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF6A4625)),
          ),
          child: ListTile(
            leading: Icon(
              item.active ? Icons.inventory_2_outlined : Icons.help_outline,
              color: item.active
                  ? const Color(0xFFE2B569)
                  : const Color(0xFFC3B5A0),
            ),
            title: Text(
              title,
              style: const TextStyle(
                color: Color(0xFFF3E4CC),
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: subtitle.isNotEmpty
                ? Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFFC3B5A0)),
                  )
                : null,
            trailing: const Icon(
              Icons.chevron_right,
              color: Color(0xFFC3B5A0),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunChip extends StatelessWidget {
  const _RunChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF120A0B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF62401F)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFFE2B569)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF3E4CC),
            ),
          ),
        ],
      ),
    );
  }
}
