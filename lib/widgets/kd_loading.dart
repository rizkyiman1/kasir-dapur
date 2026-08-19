import 'package:flutter/material.dart';

/// Layar loading standar Kasir Dapur.
///
/// Gunakan [KdLoadingView] untuk full-page loading dan [KdInlineLoader]
/// untuk loading inline di dalam konten.
class KdLoadingView extends StatelessWidget {
  const KdLoadingView({super.key, this.message = 'Memuat...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            message,
            style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Loader kecil inline — gunakan di dalam card atau list item.
class KdInlineLoader extends StatelessWidget {
  const KdInlineLoader({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
