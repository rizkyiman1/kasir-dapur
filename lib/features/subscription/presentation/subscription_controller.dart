import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_snapshot.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';

final featureGateProvider = FutureProvider<FeatureGate>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(subscriptionServiceProvider).gate(businessId);
});

final planSnapshotProvider = FutureProvider<PlanSnapshot>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(subscriptionServiceProvider).snapshot(businessId);
});

final class SubscriptionController {
  SubscriptionController(this._ref);

  final Ref _ref;

  Future<UpgradeRequestResult> requestUpgrade(BillingPlan planCode) async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final UpgradeRequestResult result = await _ref
        .read(subscriptionServiceProvider)
        .requestUpgrade(businessId: businessId, planCode: planCode);
    _invalidate();
    return result;
  }

  Future<void> restoreEntitlements() async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    await _ref
        .read(subscriptionServiceProvider)
        .restoreEntitlements(businessId);
    _invalidate();
  }

  Future<void> syncFromBackend() async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    await _ref.read(subscriptionServiceProvider).syncFromBackend(businessId);
    _invalidate();
  }

  void _invalidate() {
    _ref.invalidate(featureGateProvider);
    _ref.invalidate(planSnapshotProvider);
  }
}

final subscriptionControllerProvider = Provider<SubscriptionController>((
  Ref ref,
) {
  return SubscriptionController(ref);
});
