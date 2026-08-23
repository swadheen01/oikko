import 'package:flutter/material.dart';

/// The Oikko brand mark (`assets/oikko.png`) in a soft rounded/circular
/// frame — used on the splash screen, login/register headers, and the top
/// bar of both shells, so the same asset appears consistently everywhere
/// instead of a generic Material icon standing in for the brand.
class AppLogo extends StatelessWidget {
  final double size;
  final bool circular;
  final bool withGlassBackground;

  const AppLogo({
    super.key,
    this.size = 40,
    this.circular = true,
    this.withGlassBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = ClipRRect(
      borderRadius: circular ? BorderRadius.circular(size) : BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/oikko.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );

    if (!withGlassBackground) return image;

    return Container(
      width: size + 20,
      height: size + 20,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      alignment: Alignment.center,
      child: image,
    );
  }
}
