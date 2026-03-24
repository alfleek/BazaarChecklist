import 'package:flutter/material.dart';
import 'package:mobile/features/auth/login_page.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({
    required this.isGuest,
    required this.authLabel,
    required this.onLogout,
    super.key,
  });

  final bool isGuest;
  final String authLabel;
  final Future<void> Function()? onLogout;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SectionCard(
          title: 'Account',
          subtitle: isGuest ? 'Guest mode' : 'Signed in',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isGuest ? Icons.person_outline : Icons.verified_user,
                ),
                title: Text(isGuest ? 'Guest session' : 'Signed in'),
                subtitle: Text(authLabel),
              ),
              const SizedBox(height: 8),
              if (isGuest) ...[
                const Text(
                  'Sign in to sync your runs and item progress across devices.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _openLogin(context),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign in or create account'),
                ),
              ] else if (onLogout != null) ...[
                FilledButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Log out'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const LoginPage(),
        fullscreenDialog: true,
      ),
    );
  }
}
