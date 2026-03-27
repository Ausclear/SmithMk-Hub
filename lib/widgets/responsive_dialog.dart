import 'package:flutter/material.dart';

/// Responsive dialog wrapper — constrains width based on screen size.
/// Phone portrait: 90% width, max 360px
/// Phone landscape: max 420px
/// Tablet: max 460px
/// Desktop: max 500px
class SmithMkDialog extends StatelessWidget {
  final Widget child;
  final Color backgroundColor;
  final double borderRadius;

  const SmithMkDialog({
    super.key,
    required this.child,
    this.backgroundColor = const Color(0xFF141310),
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final isLandscape = w > h;

    double maxW;
    if (w < 600) {
      // Phone
      maxW = isLandscape ? 420 : w * 0.9;
      if (maxW > 360 && !isLandscape) maxW = 360;
    } else if (w < 960) {
      // Tablet
      maxW = 460;
    } else {
      // Desktop
      maxW = 500;
    }

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: child,
      ),
    );
  }

  /// Convenience: show a responsive dialog
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Color backgroundColor = const Color(0xFF141310),
    bool barrierDismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => SmithMkDialog(
        backgroundColor: backgroundColor,
        child: child,
      ),
    );
  }
}
