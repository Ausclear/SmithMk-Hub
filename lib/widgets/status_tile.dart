import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/smithmk_theme.dart';
import 'glass_card.dart';

class StatusTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color activeColor;
  final bool isActive;
  final VoidCallback? onTap;

  const StatusTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.activeColor = SmithMkColors.accentPrimary,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: isActive ? activeColor : null,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap?.call();
      },
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isActive ? activeColor : SmithMkColors.textTertiary)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isActive ? activeColor : SmithMkColors.textTertiary,
                  size: 22,
                ),
              ),
              if (isActive)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: activeColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: SmithMkColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isActive ? SmithMkColors.textPrimary : SmithMkColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
