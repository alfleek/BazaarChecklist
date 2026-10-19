import 'package:flutter/material.dart';

/// First-launch welcome: short app intro + sign-in vs guest (matches Bazaar theme).
/// Shared by every shell via `ShellTabIntentMixin.maybeShowFirstRunAuthPrompt`.
class FirstRunWelcomeDialog extends StatelessWidget {
  const FirstRunWelcomeDialog({
    super.key,
    required this.onSignIn,
    required this.onContinueAsGuest,
  });

  final Future<void> Function() onSignIn;
  final Future<void> Function() onContinueAsGuest;

  static const _surface = Color(0xFF1B1112);
  static const _surfaceInner = Color(0xFF241516);
  static const _border = Color(0xFF5B3A1F);
  static const _muted = Color(0xFFC3B5A0);
  static const _accentSoft = Color(0xFFE2B569);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _surfaceInner,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          Icons.emoji_events_outlined,
                          size: 28,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _accentSoft,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'BazaarChecklist',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Track your winning runs and which items you have won with. '
                  'Browse the catalog to see what you have left to unlock.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFF5E9D8),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _surfaceInner,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border.withValues(alpha: 0.85)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.cloud_outlined,
                        size: 20,
                        color: theme.colorScheme.primary.withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Sign in to sync across devices. Guest mode keeps '
                          'everything on this phone until you connect an account.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _muted,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton(
                  onPressed: onSignIn,
                  child: const Text('Sign in or create account'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: onContinueAsGuest,
                  child: const Text('Continue as guest'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
