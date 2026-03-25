import 'package:flutter/material.dart';
import 'package:mobile/features/challenges/challenge_models.dart';
import 'package:mobile/features/challenges/challenge_progress_service.dart';
import 'package:mobile/features/runs/run_result_tier.dart';
import 'package:mobile/features/runs/run_tier_visual.dart';

RunResultTier _runResultTierForChallengeTier(ChallengeChecklistTier tier) {
  return switch (tier) {
    ChallengeChecklistTier.bronze => RunResultTier.bronzeVictory,
    ChallengeChecklistTier.silver => RunResultTier.silverVictory,
    ChallengeChecklistTier.gold => RunResultTier.goldVictory,
    ChallengeChecklistTier.perfect => RunResultTier.diamondVictory,
  };
}

List<Color> _challengeTierBarGradient(ChallengeChecklistTier tier) {
  switch (tier) {
    case ChallengeChecklistTier.bronze:
      return const [Color(0xFF9A5B2A), Color(0xFFC8853F), Color(0xFFE2B569)];
    case ChallengeChecklistTier.silver:
      return const [Color(0xFF8291A2), Color(0xFFB0BCCB), Color(0xFFE3E8F0)];
    case ChallengeChecklistTier.gold:
      return const [Color(0xFFB5791F), Color(0xFFF0A223), Color(0xFFF6C97C)];
    case ChallengeChecklistTier.perfect:
      // Diamond: cool crystal highlight with subtle violet edge.
      return const [Color(0xFF6DA4D6), Color(0xFF9ED7FF), Color(0xFFD8C9FF)];
  }
}

const _kCardBorderBase = Color(0xFF5B3A1F);
const _kFractionMuted = Color(0xFFC3B5A0);

/// Tier-tinted card border (blends default brown with [RunTierStyle.accentBar]).
ShapeBorder challengeTierProgressCardShape(ChallengeChecklistTier tier) {
  final accent = RunTierStyle.forTier(_runResultTierForChallengeTier(tier)).accentBar;
  final blend = switch (tier) {
    ChallengeChecklistTier.bronze => 0.45,
    ChallengeChecklistTier.silver => 0.58,
    ChallengeChecklistTier.gold => 0.66,
    ChallengeChecklistTier.perfect => 0.74,
  };
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(
      color: Color.lerp(_kCardBorderBase, accent, blend)!,
      width: 1.2,
    ),
  );
}

/// Primary CTA using each tier’s palette ([RunTierStyle.accentBar] + [iconBackground]), not theme primary.
class ChallengeViewInCatalogButton extends StatelessWidget {
  const ChallengeViewInCatalogButton({
    required this.tier,
    required this.onPressed,
    super.key,
  });

  final ChallengeChecklistTier tier;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style = RunTierStyle.forTier(_runResultTierForChallengeTier(tier));
    // Rich tier-hued surface: mostly accent, grounded with the tier’s dark base.
    final bg = Color.lerp(style.accentBar, style.iconBackground, 0.52)!;
    final lightSurface = bg.computeLuminance() > 0.5;
    final labelColor = lightSurface
        ? const Color(0xFF1A1208)
        : Color.lerp(style.labelColor, const Color(0xFFFFFFFF), 0.06)!;
    final iconColor = lightSurface ? const Color(0xFF2A1810) : style.iconForeground;

    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: labelColor,
        iconColor: iconColor,
      ),
      icon: const Icon(Icons.tune, size: 20),
      label: const Text('View in Catalog'),
    );
  }
}

/// Compact pill showing the active checklist tier (matches [RunTierStyle] visuals).
class ChallengeTierBadge extends StatelessWidget {
  const ChallengeTierBadge({required this.tier, super.key});

  final ChallengeChecklistTier tier;

  @override
  Widget build(BuildContext context) {
    final style = RunTierStyle.forTier(_runResultTierForChallengeTier(tier));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: style.iconBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color.lerp(style.accentBar, const Color(0xFF62401F), 0.4)!,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          style.buildIcon(size: 18),
          const SizedBox(width: 6),
          Text(
            tier.label,
            style: TextStyle(
              color: style.labelColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Win-threshold dropdown shared by the Challenges hub and category detail screens.
class ChallengeWinTierDropdown extends StatelessWidget {
  const ChallengeWinTierDropdown({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final ChallengeChecklistTier value;
  final ValueChanged<ChallengeChecklistTier> onChanged;

  static String _menuLabel(ChallengeChecklistTier t) {
    if (t == ChallengeChecklistTier.perfect) return t.label;
    return '${t.label} or higher';
  }

  @override
  Widget build(BuildContext context) {
    final labelText =
        value == ChallengeChecklistTier.perfect ? 'Completely' : 'At least';
    return DropdownButtonFormField<ChallengeChecklistTier>(
      // ignore: deprecated_member_use — controlled tier; initialValue would not follow [value] updates.
      value: value,
      decoration: InputDecoration(
        labelText: labelText,
        isDense: true,
      ),
      items: ChallengeChecklistTier.values
          .map(
            (t) => DropdownMenuItem(
              value: t,
              child: Text(_menuLabel(t)),
            ),
          )
          .toList(growable: false),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class ChallengeProgressBar extends StatelessWidget {
  const ChallengeProgressBar({
    required this.progress,
    required this.tier,
    super.key,
    this.height = 10,
  });

  final ChecklistProgress progress;
  final ChallengeChecklistTier tier;
  final double height;

  @override
  Widget build(BuildContext context) {
    final barColors = _challengeTierBarGradient(tier);
    final pctColor =
        RunTierStyle.forTier(_runResultTierForChallengeTier(tier)).labelColor;
    final trackColor = switch (tier) {
      ChallengeChecklistTier.bronze => const Color(0xFF3A251B),
      ChallengeChecklistTier.silver => const Color(0xFF2A2D34),
      ChallengeChecklistTier.gold => const Color(0xFF3A2814),
      ChallengeChecklistTier.perfect => const Color(0xFF202C3A),
    };
    final ratio = progress.ratio.clamp(0.0, 1.0);
    final pct = (ratio * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: ratio),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final fillW = constraints.maxWidth * value;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              height: height,
                              width: constraints.maxWidth,
                              color: trackColor,
                            ),
                            Container(
                              height: height,
                              width: fillW,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: barColors,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 44,
              child: Text(
                '$pct%',
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: pctColor,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          progress.fractionLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Color.lerp(
                      _kFractionMuted,
                      RunTierStyle.forTier(_runResultTierForChallengeTier(tier))
                          .accentBar,
                      0.32,
                    ) ??
                    _kFractionMuted,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
