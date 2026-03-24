import 'package:flutter/material.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class ChallengesPage extends StatelessWidget {
  const ChallengesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SectionCard(
          title: 'Challenges (Stretch)',
          subtitle: 'Planned feature, UI placeholder for now.',
          child: _ChallengeContent(),
        ),
      ],
    );
  }
}

class _ChallengeContent extends StatelessWidget {
  const _ChallengeContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _ProgressRow(
          title: 'Vanessa item mastery',
          detail: '12 / 40 won with',
          progress: 0.30,
        ),
        const SizedBox(height: 12),
        const _ProgressRow(
          title: 'Burn tag coverage',
          detail: '8 / 20 won with',
          progress: 0.40,
        ),
        const SizedBox(height: 12),
        const _ProgressRow(
          title: 'Shield tag coverage',
          detail: '5 / 18 won with',
          progress: 0.28,
        ),
        const SizedBox(height: 16),
        Text(
          'Real challenge calculations will be added in a later phase.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: const Color(0xFFB5BECE)),
        ),
      ],
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.title,
    required this.detail,
    required this.progress,
  });

  final String title;
  final String detail;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 2),
        Text(
          detail,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: const Color(0xFFB5BECE)),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress,
          minHeight: 8,
          borderRadius: BorderRadius.circular(10),
        ),
      ],
    );
  }
}
