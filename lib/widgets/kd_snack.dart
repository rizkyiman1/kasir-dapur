import 'package:flutter/material.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';

/// Helper untuk menampilkan snackbar konsisten di seluruh app.
///
/// Gunakan via extension [BuildContext.kdSuccess], [BuildContext.kdError],
/// [BuildContext.kdInfo].
abstract final class KdSnack {
  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      foreground: Colors.white,
      background: const Color(0xFF2D7A4F),
    );
  }

  static void error(BuildContext context, Object error) {
    _show(
      context,
      message: ErrorHandler.userMessage(error),
      icon: Icons.error_rounded,
      foreground: Colors.white,
      background: Theme.of(context).colorScheme.error,
    );
  }

  static void warning(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      icon: Icons.warning_rounded,
      foreground: scheme.onErrorContainer,
      background: scheme.errorContainer,
    );
  }

  static void info(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    _show(
      context,
      message: message,
      icon: Icons.info_rounded,
      foreground: scheme.onPrimaryContainer,
      background: scheme.primaryContainer,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color foreground,
    required Color background,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
