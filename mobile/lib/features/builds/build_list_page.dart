import 'package:flutter/material.dart';
import 'package:mobile/features/build_input/build_input_page.dart';
import 'package:mobile/features/runs/run_record.dart';
import 'package:mobile/features/runs/run_result_tier.dart';
import 'package:mobile/features/runs/run_tier_visual.dart';
import 'package:mobile/features/runs/runs_repository.dart';

/// Bottom inset so list content can scroll clear of the floating nav + FAB.
EdgeInsets _runsListPadding(BuildContext context) {
  const horizontal = 16.0;
  const top = 16.0;
  const bottomBase = 16.0;
  const buffer = 120.0;
  return EdgeInsets.fromLTRB(
    horizontal,
    top,
    horizontal,
    bottomBase + MediaQuery.paddingOf(context).bottom + buffer,
  );
}

class BuildListPage extends StatelessWidget {
  const BuildListPage({
    required this.isGuest,
    super.key,
    this.userId,
  });

  final bool isGuest;
  final String? userId;

  @override
  Widget build(BuildContext context) {
    final repo = createRunsRepository(
      isGuest: isGuest,
      userId: userId,
    );

    return StreamBuilder<List<RunRecord>>(
      stream: repo.watchRuns(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ListView(
            padding: _runsListPadding(context),
            children: [
              _ErrorCard(message: '${snapshot.error}'),
            ],
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final runs = snapshot.data!;
        if (runs.isEmpty) {
          return ListView(
            padding: _runsListPadding(context),
            children: [
              _RunsReviewBox(runs: runs, isGuest: isGuest),
              const SizedBox(height: 12),
              const _EmptyRunsState(),
            ],
          );
        }

        return ListView(
          padding: _runsListPadding(context),
          children: [
            _RunsReviewBox(runs: runs, isGuest: isGuest),
            const SizedBox(height: 12),
            for (var i = 0; i < runs.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _RunCard(
                run: runs[i],
                isGuest: isGuest,
                userId: userId,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _RunsReviewBox extends StatelessWidget {
  const _RunsReviewBox({required this.runs, required this.isGuest});

  final List<RunRecord> runs;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final total = runs.length;
    final perfectCount =
        runs.where((r) => r.resultTier == RunResultTier.diamondVictory).length;
    final bestTier = runs.fold<RunResultTier>(
      RunResultTier.defeat,
      (acc, next) => maxRunResultTier(acc, next.resultTier),
    );

    Widget metric(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF241516),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5B3A1F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFC3B5A0),
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1112),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5B3A1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Review',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              Text(
                isGuest ? 'Local only' : 'Cloud sync',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFFC3B5A0),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              metric('Runs', '$total'),
              const SizedBox(width: 8),
              metric('Best', runResultTierShortLabel(bestTier)),
              const SizedBox(width: 8),
              metric('Perfect', '$perfectCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyRunsState extends StatelessWidget {
  const _EmptyRunsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1112),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5B3A1F)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.playlist_add_check_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No runs yet. Tap + to record hero, wins, and items.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFC3B5A0),
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1112),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF5B3A1F)),
      ),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }
}

class _RunCard extends StatelessWidget {
  const _RunCard({
    required this.run,
    required this.isGuest,
    this.userId,
  });

  final RunRecord run;
  final bool isGuest;
  final String? userId;

  static const _surfaceInner = Color(0xFF241516);
  static const _border = Color(0xFF5B3A1F);

  Color _heroAccent(String heroId) {
    final key = heroId.trim().toLowerCase();
    // Requested hero palette:
    // vanessa-red, dooley-orange, pyg-blue, mak-light green,
    // stelle-yellow, karnok-dark teal.
    if (key.contains('vanessa')) return const Color(0xFFCF4A4A);
    if (key.contains('dooley')) return const Color(0xFFE48A2B);
    if (key.contains('pyg')) return const Color(0xFF4E86D9);
    if (key.contains('mak')) return const Color(0xFF8ED6A0);
    if (key.contains('stelle')) return const Color(0xFFE6C44C);
    if (key.contains('jules')) return const Color(0xFF8A62C9);
    if (key.contains('karnok')) return const Color(0xFF2F8B95);
    final palette = <Color>[
      const Color(0xFFCF4A4A), // red
      const Color(0xFFE48A2B), // orange
      const Color(0xFF4E86D9), // blue
      const Color(0xFF8ED6A0), // light green
      const Color(0xFFE6C44C), // yellow
      const Color(0xFF2A5F66), // dark teal
      const Color(0xFF8BC48A),
    ];
    final idx = key.isEmpty ? 0 : key.codeUnitAt(0) % palette.length;
    return palette[idx];
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
    final tierLabel = runResultTierLabel(run.resultTier);
    final modeLabel = run.mode == 'ranked' ? 'Ranked' : 'Normal';
    final itemCount = run.itemIds.length;
    final tierStyle = RunTierStyle.forTier(run.resultTier);

    final heroAccent = _heroAccent(run.heroId);

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
                          Expanded(
                            child: Row(
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
                                        tierLabel,
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
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Run actions',
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.more_vert, color: Color(0xFFC3B5A0)),
                            onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => BuildInputPage(
                          isGuest: isGuest,
                          userId: userId,
                          existingRun: run,
                        ),
                      ),
                    );
                  } else if (value == 'delete') {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete run?'),
                        content: const Text(
                          'This removes the run from your history. This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !context.mounted) return;
                    final repo = createRunsRepository(
                      isGuest: isGuest,
                      userId: userId,
                    );
                    try {
                      await repo.deleteRun(run.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Run deleted.')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Could not delete run: $e')),
                      );
                    }
                  }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _ChipLabel(
                            icon: Icons.person_outline,
                            text: run.heroId,
                            bg: heroAccent.withValues(alpha: 0.18),
                            border: heroAccent.withValues(alpha: 0.7),
                            iconColor: heroAccent,
                          ),
                          _ChipLabel(
                            icon: Icons.leaderboard,
                            text: modeLabel,
                          ),
                          _ChipLabel(
                            icon: Icons.stacked_line_chart,
                            text: '${run.wins} wins',
                          ),
                          if (run.perfect)
                            _ChipLabel(
                              icon: Icons.diamond,
                              text: 'Perfect',
                            ),
                          _ChipLabel(
                            icon: Icons.inventory_2_outlined,
                            text: '$itemCount items',
                          ),
                        ],
                      ),
                      if (run.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          run.notes.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFD0C0A8),
                            height: 1.35,
                          ),
                        ),
                      ],
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

class _ChipLabel extends StatelessWidget {
  const _ChipLabel({
    required this.icon,
    required this.text,
    this.bg = const Color(0xFF120A0B),
    this.border = const Color(0xFF62401F),
    this.iconColor = const Color(0xFFE2B569),
  });

  final IconData icon;
  final String text;
  final Color bg;
  final Color border;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
