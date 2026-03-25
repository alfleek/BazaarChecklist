import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobile/features/runs/run_result_tier.dart';
/// Colors and iconography aligned loosely with in-game tier bars (bronze / silver / gold / diamond).
class RunTierStyle {
  const RunTierStyle._({
    required this.tier,
    required this.accentBar,
    required this.iconBackground,
    required this.iconForeground,
    required this.labelColor,
  });

  final RunResultTier tier;
  final Color accentBar;
  final Color iconBackground;
  final Color iconForeground;
  final Color labelColor;

  /// Trophy / symbol for this tier (defeat uses a “broken” trophy treatment).
  /// All tiers use the same bounding box so visuals align in the UI.
  Widget buildIcon({double size = 26}) {
    return _TierIcon(tier: tier, size: size);
  }

  static RunTierStyle forTier(RunResultTier tier) {
    switch (tier) {
      case RunResultTier.defeat:
        return RunTierStyle._(
          tier: tier,
          accentBar: const Color(0xFF4A3F3C),
          iconBackground: const Color(0xFF2A2220),
          iconForeground: const Color(0xFF8A7A72),
          labelColor: const Color(0xFFC4B5A8),
        );
      case RunResultTier.bronzeVictory:
        return RunTierStyle._(
          tier: tier,
          accentBar: const Color(0xFFB87333),
          iconBackground: const Color(0xFF3D2814),
          iconForeground: const Color(0xFFE8A86A),
          labelColor: const Color(0xFFE8C4A0),
        );
      case RunResultTier.silverVictory:
        return RunTierStyle._(
          tier: tier,
          accentBar: const Color(0xFFB8B8C8),
          iconBackground: const Color(0xFF2C2C34),
          iconForeground: const Color(0xFFE2E2EC),
          labelColor: const Color(0xFFE8E8F0),
        );
      case RunResultTier.goldVictory:
        return RunTierStyle._(
          tier: tier,
          accentBar: const Color(0xFFE8B84A),
          iconBackground: const Color(0xFF3D2E0A),
          iconForeground: const Color(0xFFF5D76E),
          labelColor: const Color(0xFFF5E6B8),
        );
      case RunResultTier.diamondVictory:
        return RunTierStyle._(
          tier: tier,
          accentBar: const Color(0xFF5FE8FF),
          iconBackground: const Color(0xFF2A1A45),
          iconForeground: const Color(0xFFE8FFFF),
          labelColor: const Color(0xFFFFF5E8),
        );
    }
  }
}

class _TierIcon extends StatelessWidget {
  const _TierIcon({required this.tier, required this.size});

  final RunResultTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: switch (tier) {
        RunResultTier.defeat => _defeatIcon(),
        RunResultTier.bronzeVictory ||
        RunResultTier.silverVictory ||
        RunResultTier.goldVictory =>
          Center(
            child: Icon(
              Icons.emoji_events,
              size: size,
              color: _iconColorForTier(tier),
            ),
          ),
        RunResultTier.diamondVictory => _diamondIcon(),
      },
    );
  }

  Widget _defeatIcon() {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.emoji_events_outlined,
          size: size,
          color: const Color(0xFF7A6A62),
        ),
        Icon(
          Icons.close,
          size: size * 0.42,
          color: const Color(0xFFB85C5C),
        ),
      ],
    );
  }

  /// Icy gem / “perfect” look: cyan glow, purple undertone, four-point sparkle on the cup rim.
  Widget _diamondIcon() {
    final cyan = const Color(0xFF00F0FF);
    final ice = const Color(0xFFE8FFFF);
    final lilac = const Color(0xFFD8B8FF);
    final sparkleBox = size * 0.38;

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  cyan.withValues(alpha: 0.45),
                  const Color(0xFF9B7AFF).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
        ),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ice,
                cyan,
                lilac,
                const Color(0xFF7EC8E8),
              ],
              stops: const [0.0, 0.35, 0.65, 1.0],
            ).createShader(bounds);
          },
          child: Icon(
            Icons.emoji_events,
            size: size,
            color: Colors.white,
          ),
        ),
        // Four-point star sparkle — top-right of the cup (same coordinate space as icon).
        IgnorePointer(
          child: Align(
            alignment: const Alignment(0.60, -0.90),
            child: Transform.rotate(
              angle: math.pi / 15,
              child: SizedBox(
                width: sparkleBox,
                height: sparkleBox,
                child: CustomPaint(
                  painter: _FourPointSparklePainter(
                    fillColor: ice,
                    glowColor: cyan,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Color _iconColorForTier(RunResultTier tier) {
    switch (tier) {
      case RunResultTier.defeat:
        return const Color(0xFF7A6A62);
      case RunResultTier.bronzeVictory:
        return const Color(0xFFE8A86A);
      case RunResultTier.silverVictory:
        return const Color(0xFFE2E2EC);
      case RunResultTier.goldVictory:
        return const Color(0xFFF5D76E);
      case RunResultTier.diamondVictory:
        return const Color(0xFFB8E8FF);
    }
  }
}

/// Four long points with shallow valleys (classic “✦” sparkle silhouette).
class _FourPointSparklePainter extends CustomPainter {
  _FourPointSparklePainter({
    required this.fillColor,
    required this.glowColor,
  });

  final Color fillColor;
  final Color glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final outer = math.min(size.width, size.height) * 0.46;
    final inner = outer * 0.36;

    final path = Path();
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + math.pi * i / 4;
      final r = i.isEven ? outer : inner;
      final x = cx + math.cos(angle) * r;
      final y = cy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final glowPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawPath(path, glowPaint);

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
