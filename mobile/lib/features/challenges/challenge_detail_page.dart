import 'package:flutter/material.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/catalog/catalog_item.dart';
import 'package:mobile/features/catalog/catalog_item_run_stats.dart';
import 'package:mobile/features/catalog/catalog_repository.dart';
import 'package:mobile/features/challenges/challenge_catalog_nav.dart';
import 'package:mobile/features/challenges/challenge_models.dart';
import 'package:mobile/features/challenges/challenge_progress_service.dart';
import 'package:mobile/features/challenges/challenge_widgets.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/runs_repository.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class ChallengeDetailPage extends StatefulWidget {
  const ChallengeDetailPage({
    required this.kind,
    required this.isGuest,
    this.userId,
    super.key,
  });

  final ChallengeCategoryKind kind;
  final bool isGuest;
  final String? userId;

  @override
  State<ChallengeDetailPage> createState() => _ChallengeDetailPageState();
}

class _ChallengeDetailPageState extends State<ChallengeDetailPage> {
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

  @override
  Widget build(BuildContext context) {
    final tier = sessionController.challengeChecklistTier;
    final bottomPad = MediaQuery.paddingOf(context).bottom + 28;
    if (widget.kind == ChallengeCategoryKind.fullCatalog) {
      return Scaffold(
        appBar: AppBar(title: const Text('Challenges')),
        body: const Center(child: Text('Nothing to show.')),
      );
    }

    final title = widget.kind.title;
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
              return Scaffold(
                appBar: AppBar(title: Text(title)),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load catalog: ${catSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            if (!catSnapshot.hasData) {
              return Scaffold(
                appBar: AppBar(title: Text(title)),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final catalog = catSnapshot.data!;
            final List<SubgroupProgress> subgroups;
            switch (widget.kind) {
              case ChallengeCategoryKind.heroes:
                subgroups = computeHeroSubgroupProgress(
                  catalog: catalog,
                  stats: stats,
                  tier: tier,
                );
              case ChallengeCategoryKind.typeTags:
                subgroups = computeTypeTagSubgroupProgress(
                  catalog: catalog,
                  stats: stats,
                  tier: tier,
                );
              case ChallengeCategoryKind.hiddenTypeTags:
                subgroups = computeHiddenTypeTagSubgroupProgress(
                  catalog: catalog,
                  stats: stats,
                  tier: tier,
                );
              case ChallengeCategoryKind.sizes:
                subgroups = computeSizeSubgroupProgress(
                  catalog: catalog,
                  stats: stats,
                  tier: tier,
                );
              case ChallengeCategoryKind.startingRarities:
                subgroups = computeStartingRaritySubgroupProgress(
                  catalog: catalog,
                  stats: stats,
                  tier: tier,
                );
              case ChallengeCategoryKind.fullCatalog:
                subgroups = const [];
            }

            return Scaffold(
              appBar: AppBar(title: Text(title)),
              body: ListView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPad),
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
                                  'Run history unavailable (${runSnapshot.error}). '
                                  'Progress is shown as if you have no runs.',
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
                    subtitle: '${subgroups.length} sub-checklists',
                    trailing: ChallengeTierBadge(tier: tier),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ChallengeWinTierDropdown(
                          value: tier,
                          onChanged: sessionController.setChallengeChecklistTier,
                        ),
                        const SizedBox(height: 10),
                        // Text(
                        //   'Progress counts an item when your best run with that item '
                        //   'reaches the selected tier or higher.',
                        //   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        //         color: const Color(0xFFC3B5A0),
                        //         height: 1.4,
                        //       ),
                        // ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (subgroups.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No subgroups for this category.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    for (final s in subgroups) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SubgroupCard(
                          kind: widget.kind,
                          subgroup: s,
                          tier: tier,
                        ),
                      ),
                    ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SubgroupCard extends StatelessWidget {
  const _SubgroupCard({
    required this.kind,
    required this.subgroup,
    required this.tier,
  });

  final ChallengeCategoryKind kind;
  final SubgroupProgress subgroup;
  final ChallengeChecklistTier tier;

  @override
  Widget build(BuildContext context) {
    final thresholdSubtitle = tier == ChallengeChecklistTier.perfect
        ? 'Perfect'
        : 'At least ${tier.label}';
    return SectionCard(
      title: subgroup.label,
      subtitle: thresholdSubtitle,
      shape: challengeTierProgressCardShape(tier),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChallengeProgressBar(progress: subgroup.progress, tier: tier),
          const SizedBox(height: 12),
          ChallengeViewInCatalogButton(
            tier: tier,
            onPressed: () {
              openCatalogForChallengeFilter(
                context,
                kind: kind,
                subgroupId: subgroup.id,
              );
            },
          ),
        ],
      ),
    );
  }
}
