import 'package:kasir_dapur_backend/billing/billing_database.dart';
import 'package:kasir_dapur_backend/billing/billing_repositories.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/domain/catalog.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/domain/status.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/services/entitlement_service.dart';
import 'package:uuid/uuid.dart';

final class BillingFaultHooks {
  const BillingFaultHooks({
    this.afterPaymentUpdate,
    this.afterSubscriptionUpsert,
    this.afterEntitlementReplace,
    this.afterAuditAppend,
    this.beforeCommit,
  });

  final void Function()? afterPaymentUpdate;
  final void Function()? afterSubscriptionUpsert;
  final void Function()? afterEntitlementReplace;
  final void Function()? afterAuditAppend;
  final void Function()? beforeCommit;
}

final class BillingState {
  BillingState({
    required this.db,
    required this.payments,
    required this.subscriptions,
    required this.entitlements,
    required this.webhooks,
    required this.audit,
    required this.store,
    this.faultHooks,
  });

  final BillingDatabase db;
  final PaymentRepository payments;
  final SubscriptionRepository subscriptions;
  final EntitlementRepository entitlements;
  final WebhookRepository webhooks;
  final BillingAuditRepository audit;
  final AppStore store;
  final BillingFaultHooks? faultHooks;

  static BillingState open({
    required String path,
    required AppStore store,
    BillingFaultHooks? faultHooks,
  }) {
    final BillingDatabase db = BillingDatabase.open(path);
    return BillingState(
      db: db,
      payments: PaymentRepository(db.raw),
      subscriptions: SubscriptionRepository(db.raw),
      entitlements: EntitlementRepository(db.raw),
      webhooks: WebhookRepository(db.raw),
      audit: BillingAuditRepository(db.raw),
      store: store,
      faultHooks: faultHooks,
    );
  }

  void close() => db.close();

  void hydrateCache() {
    for (final SubscriptionRecord row in subscriptions.listActive()) {
      store.entitledByBusiness[row.businessId] = row;
      store.entitlementsByBusiness[row.businessId] = entitlements.getByBusiness(
        row.businessId,
      );
    }
  }

  SubscriptionRecord ensureFree({required String businessId}) {
    final SubscriptionRecord? existing = subscriptions.findCurrentByBusiness(
      businessId,
    );
    if (existing != null && _isCurrentlyGranting(existing)) {
      store.entitledByBusiness[businessId] = existing;
      store.entitlementsByBusiness[businessId] = entitlements.getByBusiness(
        businessId,
      );
      return existing;
    }
    final SubscriptionRecord free = _newFree(businessId);
    db.transaction<void>((_) {
      subscriptions.upsert(free, subscriptionId: businessId);
      // rebuild with canonical helper to avoid drift
      seedEntitlements(store, free);
      entitlements.replaceForBusiness(
        businessId: businessId,
        planCode: BillingPlan.free,
        rows:
            store.entitlementsByBusiness[businessId] ??
            const <EntitlementRecord>[],
      );
      final int now = store.clock.nowEpochMs();
      audit.append(
        id: const Uuid().v4(),
        eventType: 'subscription.ensure_free',
        businessId: businessId,
        detail: 'Paket Free fallback aktif.',
        createdAt: now,
      );
    });
    store.entitledByBusiness[businessId] = free;
    store.entitlementsByBusiness[businessId] = entitlements.getByBusiness(
      businessId,
    );
    return free;
  }

  void activatePaid({
    required PaymentRecord payment,
    required SubscriptionCatalog catalog,
    required int verifiedAt,
  }) {
    final SubscriptionRecord? existing = subscriptions.findCurrentByBusiness(
      payment.businessId,
    );
    if (existing != null &&
        existing.status.grantsEntitlements &&
        existing.orderId == payment.orderId) {
      payment.state = CloudPaymentState.verified;
      payment.verifiedAt = verifiedAt;
      payment.updatedAt = verifiedAt;
      payments.update(payment);
      store.savePayment(payment);
      store.entitledByBusiness[payment.businessId] = existing;
      store.entitlementsByBusiness[payment.businessId] = entitlements
          .getByBusiness(payment.businessId);
      return;
    }

    final SubscriptionRecord active = SubscriptionRecord(
      id: const Uuid().v4(),
      businessId: payment.businessId,
      planCode: payment.planCode,
      status: SubscriptionStatus.active,
      source: 'midtrans',
      startsAt: verifiedAt,
      endsAt: catalog.endsAtMs(plan: payment.planCode, startsAt: verifiedAt),
      graceEndsAt:
          catalog.endsAtMs(plan: payment.planCode, startsAt: verifiedAt) == null
          ? null
          : catalog.graceEndsAtMs(
              endsAt: catalog.endsAtMs(
                plan: payment.planCode,
                startsAt: verifiedAt,
              )!,
            ),
      orderId: payment.orderId,
      verifiedAt: verifiedAt,
      createdAt: verifiedAt,
      updatedAt: verifiedAt,
    );

    seedEntitlements(store, active);
    final List<EntitlementRecord> grants =
        store.entitlementsByBusiness[payment.businessId] ??
        const <EntitlementRecord>[];

    payment.state = CloudPaymentState.verified;
    payment.verifiedAt = verifiedAt;
    payment.updatedAt = verifiedAt;
    payments.update(payment);
    faultHooks?.afterPaymentUpdate?.call();

    subscriptions.upsert(active, subscriptionId: payment.businessId);
    faultHooks?.afterSubscriptionUpsert?.call();
    entitlements.replaceForBusiness(
      businessId: payment.businessId,
      planCode: payment.planCode,
      rows: grants,
      effectiveUntil: active.graceEndsAt ?? active.endsAt,
      orderId: payment.orderId,
    );
    faultHooks?.afterEntitlementReplace?.call();
    audit.append(
      id: const Uuid().v4(),
      eventType: 'subscription.activated',
      businessId: payment.businessId,
      orderId: payment.orderId,
      detail: 'Paket ${payment.planCode.storageValue} aktif.',
      createdAt: verifiedAt,
    );
    faultHooks?.afterAuditAppend?.call();
    faultHooks?.beforeCommit?.call();

    store.savePayment(payment);
    store.entitledByBusiness[payment.businessId] = active;
    store.entitlementsByBusiness[payment.businessId] = grants;
  }

  Future<void> reconcilePending({
    required MidtransGateway midtrans,
    required SubscriptionCatalog catalog,
  }) async {
    final List<PaymentRecord> pending = payments.listPending();
    for (final PaymentRecord row in pending) {
      try {
        final MidtransStatusSnapshot remote = await midtrans.fetchStatus(
          row.orderId,
        );
        final MidtransTransactionStatus status =
            MidtransTransactionStatus.parse(remote.transactionStatus);
        row.midtransStatus = status;
        row.updatedAt = store.clock.nowEpochMs();
        if (status.isSuccess) {
          db.transaction<void>((_) {
            activatePaid(
              payment: row,
              catalog: catalog,
              verifiedAt: row.updatedAt,
            );
            audit.append(
              id: const Uuid().v4(),
              eventType: 'reconciliation.verified',
              businessId: row.businessId,
              orderId: row.orderId,
              detail: 'Pending payment terverifikasi saat startup.',
              createdAt: row.updatedAt,
            );
          });
        } else if (status.isTerminalFailure) {
          row.state = paymentStateFromMidtrans(status);
          db.transaction<void>((_) {
            payments.update(
              row,
              failureReason: 'startup_reconcile_${status.name}',
            );
            audit.append(
              id: const Uuid().v4(),
              eventType: 'reconciliation.terminal',
              businessId: row.businessId,
              orderId: row.orderId,
              detail:
                  'Status ${status.storageValue} saat startup reconciliation.',
              createdAt: row.updatedAt,
            );
          });
          store.savePayment(row);
        }
      } catch (_) {
        final int now = store.clock.nowEpochMs();
        db.transaction<void>((_) {
          audit.append(
            id: const Uuid().v4(),
            eventType: 'reconciliation.failed',
            businessId: row.businessId,
            orderId: row.orderId,
            detail: 'Gagal reconcile pending payment.',
            createdAt: now,
          );
        });
      }
    }
  }

  bool _isCurrentlyGranting(SubscriptionRecord row) {
    if (!row.status.grantsEntitlements) {
      return false;
    }
    final int now = store.clock.nowEpochMs();
    final int? grace = row.graceEndsAt;
    final int? ends = row.endsAt;
    if (grace != null && grace < now) {
      return false;
    }
    if (grace == null && ends != null && ends < now) {
      return false;
    }
    return true;
  }

  SubscriptionRecord _newFree(String businessId) {
    final int now = store.clock.nowEpochMs();
    return SubscriptionRecord(
      id: const Uuid().v4(),
      businessId: businessId,
      planCode: BillingPlan.free,
      status: SubscriptionStatus.active,
      source: 'default',
      startsAt: now,
      createdAt: now,
      updatedAt: now,
    );
  }
}
