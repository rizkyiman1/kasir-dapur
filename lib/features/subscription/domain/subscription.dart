import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';

final class Subscription {
  const Subscription({
    required this.id,
    required this.businessId,
    required this.plan,
    required this.planCode,
    required this.status,
    required this.source,
    required this.startsAt,
    this.endsAt,
    this.graceEndsAt,
    this.provider,
    this.providerOrderId,
    this.verifiedAt,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final Plan plan;
  final BillingPlan planCode;
  final SubscriptionStatus status;
  final String source;
  final int startsAt;
  final int? endsAt;
  final int? graceEndsAt;
  final String? provider;
  final String? providerOrderId;
  final int? verifiedAt;
  final int? lastSyncedAt;
  final int createdAt;
  final int updatedAt;

  bool get isActive => status == SubscriptionStatus.active;

  bool get grantsEntitlements => status.grantsEntitlements;

  bool isExpiredAt(int epochMs) {
    final int? expiry = endsAt;
    if (expiry == null) {
      return false;
    }
    return epochMs >= expiry;
  }

  bool isWithinGraceAt(int epochMs) {
    final int? grace = graceEndsAt;
    if (grace == null) {
      return false;
    }
    return epochMs < grace;
  }
}

final class Entitlement {
  const Entitlement({
    required this.id,
    required this.businessId,
    this.subscriptionId,
    required this.featureKey,
    required this.isEnabled,
    required this.limitValue,
  });

  final String id;
  final String businessId;
  final String? subscriptionId;
  final String featureKey;
  final bool isEnabled;
  final int limitValue;

  FeatureKey get key => FeatureKey.parse(featureKey);
}
