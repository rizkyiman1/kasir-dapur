import 'package:flutter/material.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';

class LegalTextPage extends StatelessWidget {
  const LegalTextPage({
    super.key,
    required this.title,
    required this.body,
    this.footerUrl = false,
  });

  final String title;
  final String body;
  final bool footerUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          if (footerUrl) ...[
            const SizedBox(height: 16),
            Text(
              Brand.websiteUrl,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ],
          const SizedBox(height: 32),
          const KdLegalFooter(),
        ],
      ),
    );
  }
}
