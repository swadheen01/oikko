import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';

/// A screen wrapper that gives every page the soft sky-blue background
/// gradient plus several faint blurred, multi-hued glow blobs instead of a
/// flat white/blue background — used as the base for most screens in the
/// app. This is the single source of the app's ambient "depth" and color
/// variety, so it stays identical on every screen automatically without
/// each page needing to opt in.
class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const GradientScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: appBar != null,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      // SizedBox.expand + StackFit.expand are both load-bearing: a bare
      // Stack sizes to its tallest non-positioned child, so on a screen
      // whose content is shorter than the viewport the gradient stopped
      // at the end of the content and the rest of the page fell through
      // to the flat scaffold colour — a visible hard edge mid-screen.
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: AppGradients.screenBackground),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // All in the blue family and kept soft: these should read as
              // one continuous wash across the page, not as separate
              // coloured patches competing with the cards on top.
              Positioned(
                top: -110,
                right: -80,
                child: _GlowBlob(color: AppColors.accent.withValues(alpha: 0.30), size: 320),
              ),
              Positioned(
                top: 220,
                left: -130,
                child: _GlowBlob(color: AppColors.primary.withValues(alpha: 0.16), size: 300),
              ),
              Positioned(
                bottom: -140,
                right: -110,
                child: _GlowBlob(color: AppColors.accentCyan.withValues(alpha: 0.18), size: 340),
              ),
              Positioned(
                bottom: 60,
                left: -120,
                child: _GlowBlob(color: AppColors.secondary.withValues(alpha: 0.12), size: 280),
              ),
              SafeArea(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0.0)],
          ),
        ),
      ),
    );
  }
}
