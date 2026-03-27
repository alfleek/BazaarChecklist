import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/runs/run_result_tier.dart';

class CatalogItemDetailPage extends StatelessWidget {
  const CatalogItemDetailPage({
    super.key,
    required this.item,
    this.stats,
    this.runsDataAvailable = true,
    this.qualifiedRunCount,
    this.winFilterActive = false,
  });

  final CatalogItem item;
  final ItemRunStats? stats;
  final bool runsDataAvailable;
  final int? qualifiedRunCount;
  final bool winFilterActive;

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF120A0B);
    const panel = Color(0xFF1C1011);
    const panelSoft = Color(0xFF241516);
    const textPrimary = Color(0xFFF3E4CC);
    const textMuted = Color(0xFFC3B5A0);
    final title = item.name.isEmpty ? item.id : item.name;
    final imageUrl = item.imageFullUrl ?? item.imageThumbUrl;
    final cacheKeyPrefix = (item.imageFullUrl != null) ? 'full' : 'thumb';
    final imageSlotHeight = 220.0;
    final slotCount = switch (item.size.trim().toLowerCase()) {
      'small' => 1,
      'medium' => 2,
      'large' => 3,
      _ => 2,
    };
    final imageSlotWidth = (imageSlotHeight / 2) * slotCount;
    final runCount = stats?.runCount ?? 0;
    final maxWins = stats?.maxWins ?? 0;
    final bestTier = stats?.bestTier ?? RunResultTier.defeat;
    final hasRuns = runCount > 0;
    final shownRunCount =
        (runsDataAvailable && winFilterActive && qualifiedRunCount != null)
        ? qualifiedRunCount!
        : runCount;
    final shownRunLabel =
        (runsDataAvailable && winFilterActive) ? 'Runs in filter' : 'Runs with item';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: textPrimary,
        elevation: 0,
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: panel,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF5D3E22)),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2A1718), Color(0xFF1A0F10)],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x50000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      width: imageSlotWidth,
                      height: imageSlotHeight,
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              cacheKey:
                                  '${cacheKeyPrefix}_v3_${item.id}_${imageUrl.hashCode}',
                              httpHeaders: const {
                                'User-Agent':
                                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
                              },
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              placeholder: (context, url) => Container(
                                color: panelSoft,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: panelSoft,
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            )
                          : Container(
                              color: panelSoft,
                              child: const Center(
                                child: Icon(Icons.image_outlined),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(
                      icon: Icons.person_outline,
                      text: item.heroTag.isEmpty ? 'Unknown hero' : item.heroTag,
                    ),
                    _Pill(
                      icon: Icons.star_outline,
                      text: item.startingRarity.isEmpty
                          ? 'Unknown rarity'
                          : item.startingRarity,
                    ),
                    _Pill(
                      icon: Icons.crop_square_outlined,
                      text: item.size.isEmpty ? 'Unknown size' : item.size,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Run performance',
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RunStatCard(
                        label: shownRunLabel,
                        value: runsDataAvailable ? '$shownRunCount' : 'N/A',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RunStatCard(
                        label: 'Highest wins',
                        value:
                            (runsDataAvailable && hasRuns) ? '$maxWins' : 'N/A',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RunStatCard(
                        label: 'Best result',
                        value: (runsDataAvailable && hasRuns)
                            ? runResultTierShortLabel(bestTier)
                            : 'No runs',
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: SizedBox.shrink()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Item details',
            child: Column(
              children: [
                _MetaLine(
                  label: 'Hero',
                  value: item.heroTag.isEmpty ? 'Unknown' : item.heroTag,
                ),
                const SizedBox(height: 8),
                _MetaLine(
                  label: 'Starting rarity',
                  value: item.startingRarity.isEmpty
                      ? 'Unknown'
                      : item.startingRarity,
                ),
                const SizedBox(height: 8),
                _MetaLine(
                  label: 'Size',
                  value: item.size.isEmpty ? 'Unknown' : item.size,
                ),
                const SizedBox(height: 8),
                _MetaLine(
                  label: 'Types',
                  value: item.typeTags.isEmpty ? 'None' : item.typeTags.join(', '),
                ),
                if (item.hiddenTags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _MetaLine(label: 'Hidden tags', value: item.hiddenTags.join(', ')),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: compare this item in Catalog filters to spot high-performing synergies.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: textMuted, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1011),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B3A1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFF3E4CC),
                ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x332B1A1B),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF8E6132)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFD7A86E)),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFF3E4CC),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _RunStatCard extends StatelessWidget {
  const _RunStatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF241516),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF7A522A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC3B5A0),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFEED9BA),
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF261718),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF704B27)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFC3B5A0),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFEED9BA),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

