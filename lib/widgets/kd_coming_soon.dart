import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';

class KdComingSoonPage extends StatelessWidget {
  const KdComingSoonPage({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      body: KdEmptyState(
        icon: Icons.construction_outlined,
        title: '$title segera hadir',
        subtitle: description,
      ),
    );
  }
}
