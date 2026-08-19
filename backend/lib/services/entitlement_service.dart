import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/domain/catalog.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/domain/status.dart';

void seedEntitlements(AppStore store, SubscriptionRecord subscription) {
  store.entitlementsByBusiness[subscription.businessId] = EntitlementCatalog
      .keys
      .map((String key) {
        final FeatureGrant grant = EntitlementCatalog.grant(
          subscription.planCode.family,
          key,
        );
        return EntitlementRecord(
          featureKey: key,
          isEnabled: grant.enabled,
          limitValue: grant.limit,
        );
      })
      .toList();
}

SubscriptionRecord ensureFree(AppStore store, String businessId) {
  final SubscriptionRecord? current = store.entitledByBusiness[businessId];
  if (current != null && current.status.grantsEntitlements) {
    return current;
  }
  final int now = store.clock.nowEpochMs();
  final SubscriptionRecord free = SubscriptionRecord(
    id: store.nextId(),
    businessId: businessId,
    planCode: BillingPlan.free,
    status: SubscriptionStatus.active,
    source: 'default',
    startsAt: now,
    createdAt: now,
    updatedAt: now,
  );
  store.entitledByBusiness[businessId] = free;
  seedEntitlements(store, free);
  store.writeAudit(
    action: 'subscription.ensure_free',
    entity: 'subscription',
    businessId: businessId,
    detail: 'Paket Free aktif tanpa pembayaran.',
  );
  return free;
}

void activatePaid({
  required AppStore store,
  required PaymentRecord payment,
  required SubscriptionCatalog catalog,
  required int verifiedAt,
}) {
  final SubscriptionRecord? previous =
      store.entitledByBusiness[payment.businessId];
  if (previous != null &&
      previous.status.grantsEntitlements &&
      previous.orderId == payment.orderId) {
    return;
  }
  if (previous != null) {
    previous.status = SubscriptionStatus.cancelled;
    previous.updatedAt = verifiedAt;
  }
  final int? endsAt = catalog.endsAtMs(
    plan: payment.planCode,
    startsAt: verifiedAt,
  );
  final SubscriptionRecord active = SubscriptionRecord(
    id: store.nextId(),
    businessId: payment.businessId,
    planCode: payment.planCode,
    status: SubscriptionStatus.active,
    source: 'midtrans',
    startsAt: verifiedAt,
    endsAt: endsAt,
    graceEndsAt: endsAt == null ? null : catalog.graceEndsAtMs(endsAt: endsAt),
    orderId: payment.orderId,
    verifiedAt: verifiedAt,
    createdAt: verifiedAt,
    updatedAt: verifiedAt,
  );
  store.entitledByBusiness[payment.businessId] = active;
  seedEntitlements(store, active);
  payment.state = CloudPaymentState.verified;
  payment.verifiedAt = verifiedAt;
  payment.updatedAt = verifiedAt;
  store.savePayment(payment);
  store.writeAudit(
    action: 'subscription.activated',
    entity: 'subscription',
    businessId: payment.businessId,
    orderId: payment.orderId,
    detail:
        'Paket ${payment.planCode.storageValue} aktif setelah verifikasi Midtrans.',
  );
}
