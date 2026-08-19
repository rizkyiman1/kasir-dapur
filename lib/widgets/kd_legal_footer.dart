import 'package:flutter/material.dart';
import 'package:kasir_dapur/config/brand.dart';

class KdLegalFooter extends StatelessWidget {
  const KdLegalFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color muted = scheme.onSurfaceVariant.withValues(alpha: 0.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${Brand.appName} · ${Brand.companyName}',
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(color: muted),
        ),
        const SizedBox(height: 2),
        Text(
          '${Brand.copyright} · ${Brand.websiteHost}',
          textAlign: TextAlign.center,
          style: text.labelSmall?.copyWith(color: muted),
        ),
      ],
    );
  }
}
