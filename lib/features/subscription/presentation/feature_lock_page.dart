import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_catalog.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';

class FeatureLockPage extends StatelessWidget {
  const FeatureLockPage({super.key, required this.feature, this.gate});

  final FeatureKey feature;
  final FeatureGate? gate;

  @override
  Widget build(BuildContext context) {
    final FeatureGate resolved =
        gate ?? FeatureGate.forPlan(PlanCatalog.minimumFor(feature));
    final String message =
        gate?.denyMessage(feature) ??
        '${feature.label} tersedia mulai paket ${PlanCatalog.minimumFor(feature).label}. Harga belum ditetapkan.';
    return Scaffold(
      appBar: AppBar(
        title: Text(feature.label),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              child: KdEmptyState(
                icon: Icons.lock_outline,
                title: 'Fitur paket ${PlanCatalog.minimumFor(feature).label}',
                subtitle: message,
              ),
            ),
            FilledButton(
              onPressed: () => context.go(AppRoutes.subscription),
              child: const Text('Lihat paket'),
            ),
            const SizedBox(height: 12),
            Text(
              'Paket saat ini: ${resolved.plan.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
