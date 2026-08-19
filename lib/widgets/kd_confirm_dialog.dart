import 'package:flutter/material.dart';

/// Dialog konfirmasi standar Kasir Dapur.
///
/// Gunakan [KdConfirmDialog.show] untuk menampilkan dialog dan mendapatkan
/// hasil `bool`.
///
/// ```dart
/// final bool? ok = await KdConfirmDialog.show(
///   context: context,
///   title: 'Batalkan transaksi?',
///   body: 'Keranjang akan dikosongkan.',
///   confirmLabel: 'Batalkan',
///   destructive: true,
/// );
/// if (ok != true) return;
/// ```
class KdConfirmDialog extends StatelessWidget {
  const KdConfirmDialog({
    super.key,
    required this.title,
    required this.body,
    this.confirmLabel = 'Konfirmasi',
    this.cancelLabel = 'Batal',
    this.destructive = false,
    this.icon,
  });

  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String body,
    String confirmLabel = 'Konfirmasi',
    String cancelLabel = 'Batal',
    bool destructive = false,
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => KdConfirmDialog(
        title: title,
        body: body,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    Widget? iconWidget;
    if (icon != null) {
      iconWidget = Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: destructive
              ? scheme.errorContainer
              : scheme.primaryContainer.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: destructive ? scheme.error : scheme.primary,
          size: 26,
        ),
      );
    }

    return AlertDialog(
      icon: iconWidget,
      title: Text(title),
      content: Text(body, style: text.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelLabel),
        ),
        if (destructive)
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          )
        else
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
      ],
    );
  }
}
