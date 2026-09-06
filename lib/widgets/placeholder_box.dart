import 'package:flutter/material.dart';
import '../theme.dart';

/// A neutral placeholder for images, logos, avatars, etc.
class PlaceholderBox extends StatelessWidget {
  const PlaceholderBox({
    super.key,
    this.width = 120,
    this.height = 120,
    this.label = 'IMAGE',
    this.icon = Icons.image_outlined,
    this.radius = 16,
  });

  final double width;
  final double height;
  final String label;
  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.glassDim,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
      ),
      // FittedBox because a placeholder is often given a small fixed box; at a
      // large system font scale the label would otherwise overflow it.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.faint, size: width * 0.28),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(label, style: AppText.eyebrow),
            ],
          ],
        ),
      ),
    );
  }
}