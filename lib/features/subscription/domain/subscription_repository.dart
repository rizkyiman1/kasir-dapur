import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';

abstract class SubscriptionRepository {
  Future<Subscription> upsertPlan({
    required String businessId,
    required Plan plan,
    required String source,
    required int startsAt,
    int? endsAt,
    BillingPlan? planCode,
    SubscriptionStatus status = SubscriptionStatus.active,
    int? graceEndsAt,
    String? provider,
    String? providerOrderId,
    int? verifiedAt,
    bool seedEntitlements = true,
    bool supersedeCurrent = true,
  });

  Future<Subscription?> current(String businessId);

  Future<Subscription?> latestPending(String businessId);

  Future<List<Subscription>> listSubscriptions(String businessId);

  Future<void> updateStatus({
    required String id,
    required SubscriptionStatus status,
    int? graceEndsAt,
    int? lastSyncedAt,
  });

  Future<void> replaceEntitlements({
    required String businessId,
    required String subscriptionId,
    required Plan plan,
  });
}
