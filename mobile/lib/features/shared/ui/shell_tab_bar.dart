import 'package:flutter/material.dart';

/// App bar title for root tab shell: icon + title + subtitle (Bazaar theme).
///
/// The leading icon is decorative only (not tappable). Avoid bordered “chips”
/// here—they read like extra buttons next to real [AppBar] actions.
class ShellTabAppBarTitle extends StatelessWidget {
  const ShellTabAppBarTitle({
    required this.title,
    required this.subtitle,
    required this.icon,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  /// Muted gold so the glyph reads as a label accent, not a primary action.
  static const _decorativeIcon = Color(0xFFE2B569);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ExcludeSemantics(
          child: Icon(
            icon,
            size: 22,
            color: _decorativeIcon.withValues(alpha: 0.82),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFFC3B5A0),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Background + subtle gold accent strip for shell [AppBar].
class ShellAppBarFlexibleSpace extends StatelessWidget {
  const ShellAppBarFlexibleSpace({super.key});

  static const _surface = Color(0xFF1B1112);
  static const _accent = Color(0xFFF0A223);

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: _surface),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 2,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  _accent.withValues(alpha: 0),
                  _accent.withValues(alpha: 0.5),
                  _accent.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
