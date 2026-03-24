import 'package:flutter/material.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class BuildListPage extends StatelessWidget {
  const BuildListPage({
    required this.isGuest,
    required this.showOnboardingCard,
    required this.onDismissOnboardingCard,
    required this.onSignInRequested,
    super.key,
  });

  final bool isGuest;
  final bool showOnboardingCard;
  final VoidCallback onDismissOnboardingCard;
  final VoidCallback onSignInRequested;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isGuest && showOnboardingCard)
          _GuestOnboardingCard(
            onStartTracking: onDismissOnboardingCard,
            onSignInRequested: onSignInRequested,
          ),
        SectionCard(
          title: 'Runs',
          subtitle: 'Review your saved runs and item progress snapshots.',
          child: Column(
            children: const [
              _BuildListTile(
                title: 'Gold victory - Vanessa',
                subtitle: 'Ranked - 10 wins - 4 items tracked',
              ),
              SizedBox(height: 8),
              _BuildListTile(
                title: 'Silver victory - Dooley',
                subtitle: 'Normal - 8 wins - Notes attached',
              ),
              SizedBox(height: 8),
              _BuildListTile(
                title: 'Bronze victory - Pyg',
                subtitle: 'Ranked - 5 wins',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BuildListTile extends StatelessWidget {
  const _BuildListTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF241516),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5B3A1F)),
      ),
      child: ListTile(
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Color(0xFFD0C0A8)),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _GuestOnboardingCard extends StatelessWidget {
  const _GuestOnboardingCard({
    required this.onStartTracking,
    required this.onSignInRequested,
  });

  final VoidCallback onStartTracking;
  final VoidCallback onSignInRequested;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Welcome to BazaarChecklist',
      subtitle: 'You are in guest mode.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Track winning runs and build item coverage over time.'),
          const SizedBox(height: 8),
          const Text('Sign in later to sync your progress across devices.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onStartTracking,
            child: const Text('Start tracking'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSignInRequested,
            child: const Text('Sign in to sync'),
          ),
        ],
      ),
    );
  }
}
