import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/entitlement_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_history_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_status.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_snapshot.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_payment.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:uuid/uuid.dart';

final class UpgradeRequestResult {
  const UpgradeRequestResult({
    required this.payment,
    required this.pending,
    this.checkout,
    this.checkoutError,
  });

  final SubscriptionPayment payment;
  final Subscription pending;
  final CheckoutSession? checkout;
  final String? checkoutError;
}

/// Orkestrasi langganan. Paket berbayar hanya aktif setelah verifikasi backend.
final class SubscriptionService {
  SubscriptionService({
    required SubscriptionRepository store,
    required EntitlementRepository entitlements,
    required PaymentHistoryRepository payments,
    required BillingGateway billing,
    required SubscriptionConfig config,
    required ClockService clock,
    required PermissionGuard guard,
    required AccessContext Function() access,
    Uuid? uuid,
  }) : _store = store,
       _entitlements = entitlements,
       _payments = payments,
       _billing = billing,
       _config = config,
       _clock = clock,
       _guard = guard,
       _access = access,
       _uuid = uuid ?? const Uuid();

  static const String defaultSource = 'default';
  static const String backendSource = 'backend';

  final SubscriptionRepository _store;
  final EntitlementRepository _entitlements;
  final PaymentHistoryRepository _payments;
  final BillingGateway _billing;
  final SubscriptionConfig _config;
  final ClockService _clock;
  final PermissionGuard _guard;
  final AccessContext Function() _access;
  final Uuid _uuid;

  Future<Subscription> ensureDefault(String businessId) async {
    await refreshLifecycle(businessId);
    final Subscription? existing = await _store.current(businessId);
    final List<Entitlement> rows = await _entitlements.list(businessId);
    if (existing != null && rows.isNotEmpty) {
      return existing;
    }
    if (existing != null && rows.isEmpty) {
      await _store.replaceEntitlements(
        businessId: businessId,
        subscriptionId: existing.id,
        plan: existing.plan,
      );
      return existing;
    }
    return _store.upsertPlan(
      businessId: businessId,
      plan: Plan.free,
      planCode: BillingPlan.free,
      source: defaultSource,
      provider: SubscriptionConfig.providerDefault,
      startsAt: _clock.nowEpochMs(),
    );
  }

  Future<FeatureGate> gate(String businessId) async {
    final Subscription current = await ensureDefault(businessId);
    if (!current.grantsEntitlements) {
      return FeatureGate.forPlan(Plan.free);
    }
    final List<Entitlement> rows = await _entitlements.list(businessId);
    return FeatureGate.fromEntitlements(rows, plan: current.plan);
  }

  Future<Subscription> currentPlan(String businessId) {
    return ensureDefault(businessId);
  }

  Future<PlanSnapshot> snapshot(String businessId) async {
    final Subscription current = await ensureDefault(businessId);
    return PlanSnapshot(
      subscription: current,
      entitlements: await _entitlements.list(businessId),
      pending: await _store.latestPending(businessId),
      payments: await _payments.listPayments(businessId),
    );
  }

  Future<List<SubscriptionPayment>> paymentHistory(String businessId) {
    return _payments.listPayments(businessId);
  }

  /// Tombol pembayaran hanya membuat pending. Tidak mengaktifkan paket.
  Future<UpgradeRequestResult> requestUpgrade({
    required String businessId,
    required BillingPlan planCode,
  }) async {
    _guard.require(_access(), AppPermission.manageSubscription);
    if (!planCode.isPaid) {
      throw const ValidationException(
        'Paket Free tidak memerlukan pembayaran.',
      );
    }
    await ensureDefault(businessId);
    final Subscription? entitled = await _store.current(businessId);
    if (entitled != null &&
        entitled.planCode == planCode &&
        entitled.grantsEntitlements) {
      throw const ValidationException('Paket ini sudah aktif.');
    }
    final int now = _clock.nowEpochMs();
    final PlanOffer offer = _config.offerOf(planCode);
    final Subscription pending = await _store.upsertPlan(
      businessId: businessId,
      plan: planCode.family,
      planCode: planCode,
      source: backendSource,
      provider: SubscriptionConfig.providerMidtrans,
      startsAt: now,
      status: SubscriptionStatus.pending,
      seedEntitlements: false,
      supersedeCurrent: false,
    );
    final String clientUuid = _uuid.v4();
    SubscriptionPayment payment = await _payments.insertPayment(
      businessId: businessId,
      subscriptionId: pending.id,
      planCode: planCode,
      amountRupiah: offer.priceRupiah ?? 0,
      currency: SubscriptionConfig.currency,
      status: PaymentStatus.pending,
      provider: SubscriptionConfig.providerMidtrans,
      clientUuid: clientUuid,
    );
    CheckoutSession? checkout;
    String? checkoutError;
    try {
      checkout = await _billing.createCheckout(
        CheckoutRequest(
          businessId: businessId,
          planCode: planCode,
          clientUuid: clientUuid,
        ),
      );
      payment = await _payments.updatePayment(
        id: payment.id,
        providerOrderId: checkout.orderId,
        snapToken: checkout.snapToken,
        snapRedirectUrl: checkout.snapRedirectUrl,
      );
    } on Object catch (error) {
      checkoutError = error.toString();
      payment = await _payments.updatePayment(
        id: payment.id,
        failureReason: checkoutError,
      );
    }
    return UpgradeRequestResult(
      payment: payment,
      pending: pending,
      checkout: checkout,
      checkoutError: checkoutError,
    );
  }

  /// Terapkan payload yang sudah diverifikasi server (webhook/sync).
  Future<Subscription> applyVerifiedEntitlement(
    VerifiedSubscription payload,
  ) async {
    if (!payload.grantsEntitlements) {
      await refreshLifecycle(payload.businessId);
      return ensureDefault(payload.businessId);
    }
    final int startsAt = payload.startsAt;
    final int? endsAt =
        payload.endsAt ??
        _config.endsAtMs(planCode: payload.planCode, startsAt: startsAt);
    final int? graceEndsAt =
        payload.graceEndsAt ??
        (endsAt == null ? null : _config.graceEndsAtMs(endsAt: endsAt));
    final Subscription active = await _store.upsertPlan(
      businessId: payload.businessId,
      plan: payload.planCode.family,
      planCode: payload.planCode,
      source: backendSource,
      provider: payload.provider,
      providerOrderId: payload.orderId,
      startsAt: startsAt,
      endsAt: endsAt,
      graceEndsAt: graceEndsAt,
      verifiedAt: payload.verifiedAt,
      status: payload.status,
    );
    final SubscriptionPayment? payment = await _payments.findPaymentByOrderId(
      payload.orderId,
    );
    if (payment != null) {
      await _payments.updatePayment(
        id: payment.id,
        status: PaymentStatus.verified,
        subscriptionId: active.id,
        providerOrderId: payload.orderId,
        verifiedAt: payload.verifiedAt,
      );
    }
    final Subscription? pending = await _store.latestPending(
      payload.businessId,
    );
    if (pending != null) {
      await _store.updateStatus(
        id: pending.id,
        status: SubscriptionStatus.cancelled,
      );
    }
    return active;
  }

  Future<Subscription> syncFromBackend(String businessId) async {
    final VerifiedSubscription? payload = await _billing.fetchVerified(
      businessId,
    );
    if (payload == null) {
      return ensureDefault(businessId);
    }
    return applyVerifiedEntitlement(payload);
  }

  Future<Subscription> restoreEntitlements(String businessId) async {
    try {
      await syncFromBackend(businessId);
    } on Object {
      await refreshLifecycle(businessId);
    }
    final Subscription current = await ensureDefault(businessId);
    await _store.replaceEntitlements(
      businessId: businessId,
      subscriptionId: current.id,
      plan: current.grantsEntitlements ? current.plan : Plan.free,
    );
    return current;
  }

  Future<void> refreshLifecycle(String businessId) async {
    final Subscription? entitled = await _store.current(businessId);
    if (entitled == null) {
      return;
    }
    final int now = _clock.nowEpochMs();
    final int? endsAt = entitled.endsAt;
    if (endsAt == null || now < endsAt) {
      return;
    }
    if (entitled.isWithinGraceAt(now)) {
      if (entitled.status != SubscriptionStatus.gracePeriod) {
        await _store.updateStatus(
          id: entitled.id,
          status: SubscriptionStatus.gracePeriod,
          graceEndsAt: entitled.graceEndsAt,
        );
      }
      return;
    }
    await _store.updateStatus(
      id: entitled.id,
      status: SubscriptionStatus.expired,
    );
    await _store.upsertPlan(
      businessId: businessId,
      plan: Plan.free,
      planCode: BillingPlan.free,
      source: defaultSource,
      provider: SubscriptionConfig.providerDefault,
      startsAt: now,
    );
  }

  Future<void> requireFeature({
    required String businessId,
    required FeatureKey key,
  }) async {
    final FeatureGate current = await gate(businessId);
    current.require(key);
  }

  Future<void> requireLimit({
    required String businessId,
    required FeatureKey key,
    required int used,
  }) async {
    final FeatureGate current = await gate(businessId);
    current.requireWithinLimit(key, used);
  }
}
