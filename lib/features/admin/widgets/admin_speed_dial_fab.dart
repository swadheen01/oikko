import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../finance/screens/add_expense_screen.dart';
import '../../finance/screens/add_payment_screen.dart';
import '../screens/add_member_screen.dart';

/// The admin's global "+" button (present on every admin screen, not just
/// one tab) — expands into "Add payment", "Add member", and "Member IDs"
/// shortcuts, the most frequent bulk actions for a large association. The expanded
/// backdrop + mini actions are pushed via the root `Overlay` (not nested
/// inside this widget's own small Stack) since Scaffold only gives its
/// `floatingActionButton` slot a tightly-sized area — a `Positioned.fill`
/// placed directly inside that slot would only cover the FAB itself, not
/// the screen.
class AdminSpeedDialFab extends StatefulWidget {
  const AdminSpeedDialFab({super.key});

  @override
  State<AdminSpeedDialFab> createState() => _AdminSpeedDialFabState();
}

class _AdminSpeedDialFabState extends State<AdminSpeedDialFab> {
  OverlayEntry? _entry;

  bool get _isOpen => _entry != null;

  void _toggle() => _isOpen ? _close() : _open();

  void _open() {
    final overlay = Overlay.of(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              child: Container(color: Colors.black.withValues(alpha: 0.25)),
            ),
          ),
          Positioned(
            right: 16,
            // Clears the bottom nav bar (64) + the FAB itself sitting above it.
            bottom: 64 + bottomInset + 90,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Members" used to live here; it has its own tab now, so
                // listing it again would just be a second door to the same
                // room.
                _MiniAction(
                  label: AppStrings.addMember,
                  icon: Icons.person_add_rounded,
                  color: AppColors.accentViolet,
                  onTap: () => _select(const AddMemberScreen()),
                ),
                const SizedBox(height: AppDimensions.sm),
                _MiniAction(
                  label: AppStrings.addPayment,
                  icon: Icons.payments_rounded,
                  color: AppColors.accentTeal,
                  onTap: () => _select(const AddPaymentScreen()),
                ),
                const SizedBox(height: AppDimensions.sm),
                _MiniAction(
                  label: AppStrings.addExpense,
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.danger,
                  onTap: () => _select(const AddExpenseScreen()),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  void _select(Widget screen) {
    _close();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppGradients.button,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AnimatedRotation(
              turns: _isOpen ? 0.125 : 0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniAction({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            boxShadow: [
              BoxShadow(color: AppColors.shadowAmbient, blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Text(label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: AppDimensions.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
