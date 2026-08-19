import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/presentation/feature_lock_page.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';

/// Bungkus halaman berbayar. Cek lewat FeatureGate, bukan nama paket.
class EntitlementPage extends ConsumerWidget {
  const EntitlementPage({
    super.key,
    required this.feature,
    required this.child,
  });

  final FeatureKey feature;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FeatureGate> gate = ref.watch(featureGateProvider);
    return gate.when(
      loading: () =>
          const Scaffold(body: KdLoadingView(message: 'Memeriksa paket...')),
      error: (Object error, StackTrace _) => FeatureLockPage(feature: feature),
      data: (FeatureGate data) {
        if (!data.canUse(feature)) {
          return FeatureLockPage(feature: feature, gate: data);
        }
        return child;
      },
    );
  }
}
