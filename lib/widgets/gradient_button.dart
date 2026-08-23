import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';
import '../core/theme/app_text_styles.dart';
import '../core/constants/app_dimensions.dart';

/// Premium gradient button used for all primary actions (login, submit,
/// save) across the app — replaces the default flat ElevatedButton.
/// Has a subtle glass sheen, a colorful layered glow shadow, and a
/// press-down scale animation for a more tactile, premium feel.
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: AppDimensions.buttonHeight,
      child: AnimatedScale(
        scale: _pressed && !disabled ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: disabled
                ? LinearGradient(colors: [Colors.grey.shade400, Colors.grey.shade400])
                : AppGradients.button,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.26),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: AppColors.accentViolet.withValues(alpha: 0.22),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: Stack(
              children: [
                // Glass sheen — a faint top-left highlight so the fill
                // reads as glossy/lifted rather than a flat color block.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.glassSheen),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: disabled ? null : widget.onPressed,
                    onTapDown: (_) => _setPressed(true),
                    onTapCancel: () => _setPressed(false),
                    onTapUp: (_) => _setPressed(false),
                    splashColor: Colors.white.withValues(alpha: 0.15),
                    highlightColor: Colors.white.withValues(alpha: 0.08),
                    child: Center(
                      child: widget.isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor: AlwaysStoppedAnimation(AppColors.textOnPrimary),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icon != null) ...[
                                  Icon(widget.icon, color: AppColors.textOnPrimary, size: AppDimensions.iconSm),
                                  const SizedBox(width: AppDimensions.sm),
                                ],
                                Text(widget.label, style: AppTextStyles.button),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
