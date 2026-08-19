import 'package:flutter/material.dart';

/// Card section standar Kasir Dapur.
///
/// Opsional: tambahkan [title] dan/atau [trailing] untuk header section.
class KdSectionCard extends StatelessWidget {
  const KdSectionCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.title,
    this.trailing,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Judul section opsional, ditampilkan di atas card.
  final String? title;

  /// Widget trailing di kanan judul (mis. TextButton "Lihat semua").
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(padding: padding, child: child);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ],
        Card(
          clipBehavior: Clip.antiAlias,
          child: onTap == null
              ? content
              : InkWell(onTap: onTap, child: content),
        ),
      ],
    );
  }
}
