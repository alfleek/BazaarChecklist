import 'package:flutter/material.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';
import 'package:mobile/features/challenges/challenge_catalog_nav.dart';
import 'package:mobile/features/challenges/challenge_detail_page.dart';
import 'package:mobile/features/challenges/challenge_models.dart';
import 'package:mobile/features/challenges/challenge_progress_service.dart';
import 'package:mobile/features/challenges/challenge_widgets.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/runs_repository.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class ChallengesPage extends StatefulWidget {
  const ChallengesPage({
    required this.isGuest,
    super.key,
    this.userId,
  });

  final bool isGuest;
  final String? userId;

  @override
  State<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends State<ChallengesPage> {
  @override
  void initState() {
    super.initState();
    sessionController.challengeTierListenable.addListener(_onTierChanged);
  }

  @override
  void dispose() {
    sessionController.challengeTierListenable.removeListener(_onTierChanged);
    super.dispose();
  }

  void _onTierChanged() => setState(() {});

  Future<void> _openDetail(ChallengeCategoryKind kind) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChallengeDetailPage(
          kind: kind,
          isGuest: widget.isGuest,
          userId: widget.userId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tier = sessionController.challengeChecklistTier;
    final runsRepo = createRunsRepository(
      isGuest: widget.isGuest,
      userId: widget.userId,
    );

    return StreamBuilder<List<RunRecord>>(
      stream: runsRepo.watchRuns(),
      builder: (context, runSnapshot) {
        final runsErrored = runSnapshot.hasError;
        final runs = runSnapshot.hasData ? runSnapshot.data! : const <RunRecord>[];
        final stats = runsErrored ? <String, ItemRunStats>{} : buildItemRunStatsMap(runs);

        return StreamBuilder<List<CatalogItem>>(
          stream: catalogRepository.watchActiveCatalogItems(),
          builder: (context, catSnapshot) {
            if (catSnapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SectionCard(
                    title: 'Challenges',
                    subtitle: 'Could not load catalog',
                    child: Text('${catSnapshot.error}'),
                  ),
                ],
              );
            }
            if (!catSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final catalog = catSnapshot.data!;
            final full = computeFullCatalogProgress(
              catalog: catalog,
              stats: stats,
              tier: tier,
            );

            final heroSub = computeHeroSubgroupProgress(
              catalog: catalog,
              stats: stats,
              tier: tier,
            );
            final tagSub = computeTypeTagSubgroupProgress(
              catalog: catalog,
              stats: stats,
              tier: tier,
            );
            final sizeSub = computeSizeSubgroupProgress(
              catalog: catalog,
              stats: stats,
              tier: tier,
            );
            final raritySub = computeStartingRaritySubgroupProgress(
              catalog: catalog,
              stats: stats,
              tier: tier,
            );

            final heroRoll = rollupSumSubgroups(heroSub);
            final tagRoll = rollupSumSubgroups(tagSub);
            final sizeRoll = rollupSumSubgroups(sizeSub);
            final rarityRoll = rollupSumSubgroups(raritySub);

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (runsErrored)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: const Color(0xFF241516),
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
                                'Progress assumes no runs.',
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
                SectionCard(
                  title: 'Win threshold',
                  subtitle: 'Uses your best run per item.',
                  trailing: ChallengeTierBadge(tier: tier),
                  child: ChallengeWinTierDropdown(
                    value: tier,
                    onChanged: sessionController.setChallengeChecklistTier,
                  ),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: ChallengeCategoryKind.fullCatalog.title,
                  subtitle: ChallengeCategoryKind.fullCatalog.subtitle,
                  shape: challengeTierProgressCardShape(tier),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ChallengeProgressBar(progress: full, tier: tier),
                      const SizedBox(height: 12),
                      ChallengeViewInCatalogButton(
                        tier: tier,
                        onPressed: () {
                          openCatalogForChallengeFilter(
                            context,
                            kind: ChallengeCategoryKind.fullCatalog,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _ChallengeHubRow(
                  kind: ChallengeCategoryKind.heroes,
                  rollup: heroRoll,
                  subgroupCount: heroSub.length,
                  tier: tier,
                  onTap: () => _openDetail(ChallengeCategoryKind.heroes),
                ),
                const SizedBox(height: 10),
                _ChallengeHubRow(
                  kind: ChallengeCategoryKind.typeTags,
                  rollup: tagRoll,
                  subgroupCount: tagSub.length,
                  tier: tier,
                  onTap: () => _openDetail(ChallengeCategoryKind.typeTags),
                ),
                const SizedBox(height: 10),
                _ChallengeHubRow(
                  kind: ChallengeCategoryKind.sizes,
                  rollup: sizeRoll,
                  subgroupCount: sizeSub.length,
                  tier: tier,
                  onTap: () => _openDetail(ChallengeCategoryKind.sizes),
                ),
                const SizedBox(height: 10),
                _ChallengeHubRow(
                  kind: ChallengeCategoryKind.startingRarities,
                  rollup: rarityRoll,
                  subgroupCount: raritySub.length,
                  tier: tier,
                  onTap: () => _openDetail(ChallengeCategoryKind.startingRarities),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ChallengeHubRow extends StatelessWidget {
  const _ChallengeHubRow({
    required this.kind,
    required this.rollup,
    required this.subgroupCount,
    required this.tier,
    required this.onTap,
  });

  final ChallengeCategoryKind kind;
  final ChecklistProgress rollup;
  final int subgroupCount;
  final ChallengeChecklistTier tier;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: challengeTierProgressCardShape(tier),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          kind.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$subgroupCount sub-checklists · ${kind.subtitle}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: const Color(0xFFC3B5A0),
                                height: 1.35,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFFC3B5A0)),
                ],
              ),
              const SizedBox(height: 12),
              ChallengeProgressBar(progress: rollup, tier: tier),
            ],
          ),
        ),
      ),
    );
  }
}
