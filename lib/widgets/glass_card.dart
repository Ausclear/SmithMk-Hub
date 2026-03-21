import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/smithmk_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? glowColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 20,
    this.onTap,
    this.onLongPress,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: SmithMkColors.glassOverlay,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: SmithMkColors.glassBorder,
              width: 1.0,
            ),
            boxShadow: glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor!.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: -5,
                    ),
                  ]
                : null,
          ),
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

    if (onTap != null || onLongPress != null) {
      return GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: card,
      );
    }

    return card;
  }
}
