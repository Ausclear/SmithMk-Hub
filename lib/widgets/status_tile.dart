import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/smithmk_theme.dart';
import 'glass_card.dart';

class StatusTile extends StatefulWidget {
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
  State<StatusTile> createState() => _StatusTileState();
}

class _StatusTileState extends State<StatusTile> with SingleTickerProviderStateMixin {
  late AnimationController _tapController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnim.value,
        child: child,
      ),
      child: GlassCard(
        glowColor: widget.isActive ? widget.activeColor : null,
        onTap: () {
          HapticFeedback.lightImpact();
          _tapController.forward().then((_) => _tapController.reverse());
          widget.onTap?.call();
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
                    color: (widget.isActive ? widget.activeColor : SmithMkColors.textTertiary)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isActive ? widget.activeColor : SmithMkColors.textTertiary,
                    size: 22,
                  ),
                ),
                if (widget.isActive)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.activeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: widget.activeColor.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: SmithMkColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: widget.isActive ? SmithMkColors.textPrimary : SmithMkColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
