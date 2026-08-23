import 'dart:ui';

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';
import '../core/constants/app_dimensions.dart';

/// The single card treatment used across the app: a hairline glass border
/// plus a two-layer shadow (wide ambient glow + tight contact shadow).
/// Every list item, info tile, and form card should wrap its content in
/// this instead of hand-rolling a Container/BoxDecoration — that is what
/// keeps every screen's "lift" consistent.
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppDimensions.md),
    this.radius = AppDimensions.radiusLg,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);

    // Frosted glass rather than a flat panel: a blur of whatever sits
    // behind, a translucent fill so the screen gradient tints through, and
    // a bright hairline along the top edge where light would catch the lip.
    final content = ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? AppColors.glassFill,
            borderRadius: shape,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppGradients.glassEdge,
              borderRadius: shape,
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );

    // The shadow lives outside the ClipRRect — clipped, it would be
    // cropped away by the very rectangle it's meant to sit under.
    final lifted = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowAmbient,
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: AppColors.shadowContact,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: content,
    );

    if (onTap == null) return lifted;

    return Material(
      color: Colors.transparent,
      borderRadius: shape,
      child: InkWell(
        borderRadius: shape,
        onTap: onTap,
        child: lifted,
      ),
    );
  }
}
