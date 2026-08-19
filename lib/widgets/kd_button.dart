import 'package:flutter/material.dart';

/// Tombol standar Kasir Dapur.
///
/// - Loading state menampilkan spinner di tengah.
/// - [expand] = true untuk full-width (default).
/// - [destructive] = true untuk warna merah (hapus, batalkan).
class KdButton extends StatelessWidget {
  const KdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.expand = true,
    this.loading = false,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool expand;
  final bool loading;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Widget child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: destructive ? scheme.onError : scheme.onPrimary,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final ButtonStyle style = FilledButton.styleFrom(
      minimumSize: expand ? const Size.fromHeight(48) : const Size(88, 48),
      backgroundColor: destructive ? scheme.error : null,
      foregroundColor: destructive ? scheme.onError : null,
    );

    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: child,
    );
  }
}
