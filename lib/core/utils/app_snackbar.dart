import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// App-level snackbars that survive a screen swap.
///
/// Login and logout both tear down the whole widget tree the moment they
/// succeed (AuthWrapper rebuilds from the auth stream), so a snackbar shown
/// through `ScaffoldMessenger.of(context)` on the *outgoing* screen is
/// disposed before it ever paints — which is why signing in and out used to
/// give no confirmation at all. Routing through a single messenger owned by
/// MaterialApp keeps the message alive across that rebuild.
class AppSnackbar {
  static final GlobalKey<ScaffoldMessengerState> key =
      GlobalKey<ScaffoldMessengerState>();

  static void _show(String message, Color background, IconData icon) {
    final messenger = key.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  static void success(String message) =>
      _show(message, AppColors.success, Icons.check_circle_rounded);

  static void info(String message) =>
      _show(message, AppColors.primary, Icons.info_rounded);

  static void error(String message) =>
      _show(message, AppColors.danger, Icons.error_rounded);
}
