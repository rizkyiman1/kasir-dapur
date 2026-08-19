import 'package:kasir_dapur_backend/billing/billing_state.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/domain/catalog.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/domain/status.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:sqlite3/sqlite3.dart';

final class CheckoutResult {
  const CheckoutResult({
    required this.orderId,
    required this.planCode,
    required this.amountRupiah,
    required this.snapToken,
    required this.snapRedirectUrl,
  });

  final String orderId;
  final BillingPlan planCode;
  final int amountRupiah;
  final String snapToken;
  final String snapRedirectUrl;

  Map<String, Object> toJson() {
    return <String, Object>{
      'order_id': orderId,
      'plan_code': planCode.storageValue,
      'amount': amountRupiah,
      'snap_token': snapToken,
      'snap_redirect_url': snapRedirectUrl,
    };
  }
}

final class CheckoutService {
  CheckoutService({
    required this.store,
    required this.catalog,
    required this.midtrans,
    required this.billing,
  });

  final AppStore store;
  final SubscriptionCatalog catalog;
  final MidtransGateway midtrans;
  final BillingState billing;

  Future<CheckoutResult> create({
    required String businessId,
    required String planCodeRaw,
    required String clientUuid,
  }) async {
    if (businessId.isEmpty || clientUuid.isEmpty) {
      throw const FormatException('business_id dan client_uuid wajib.');
    }
    final BillingPlan plan = BillingPlan.parse(planCodeRaw);
    final int amount = catalog.requireAmount(plan);
    billing.ensureFree(businessId: businessId);

    PaymentRecord? existing = billing.payments.findByClientUuid(clientUuid);
    if (existing != null && existing.state == CloudPaymentState.pending) {
      if (existing.businessId != businessId) {
        throw const FormatException(
          'client_uuid sudah digunakan oleh bisnis lain.',
        );
      }
      if (existing.planCode != plan) {
        throw const FormatException(
          'client_uuid sudah terpakai untuk paket berbeda.',
        );
      }
      return CheckoutResult(
        orderId: existing.orderId,
        planCode: existing.planCode,
        amountRupiah: existing.amountRupiah,
        snapToken: existing.snapToken ?? '',
        snapRedirectUrl: existing.snapRedirectUrl ?? '',
      );
    }

    final int now = store.clock.nowEpochMs();
    final String orderId = 'KD-$clientUuid-${store.nextId()}';
    final PaymentRecord payment = PaymentRecord(
      id: store.nextId(),
      businessId: businessId,
      planCode: plan,
      amountRupiah: amount,
      currency: SubscriptionCatalog.currency,
      clientUuid: clientUuid,
      orderId: orderId,
      state: CloudPaymentState.pending,
      midtransStatus: MidtransTransactionStatus.pending,
      createdAt: now,
      updatedAt: now,
    );
    try {
      billing.db.transaction<void>((_) {
        billing.payments.create(payment);
        billing.audit.append(
          id: store.nextId(),
          eventType: 'checkout_created',
          businessId: businessId,
          orderId: orderId,
          detail: 'Checkout ${plan.storageValue} pending.',
          createdAt: now,
        );
      });
    } on SqliteException catch (error) {
      if (error.resultCode == SqlError.SQLITE_CONSTRAINT) {
        existing = billing.payments.findByClientUuid(clientUuid);
        if (existing != null && existing.state == CloudPaymentState.pending) {
          if (existing.businessId != businessId) {
            throw const FormatException(
              'client_uuid sudah digunakan oleh bisnis lain.',
            );
          }
          if (existing.planCode != plan) {
            throw const FormatException(
              'client_uuid sudah terpakai untuk paket berbeda.',
            );
          }
          return CheckoutResult(
            orderId: existing.orderId,
            planCode: existing.planCode,
            amountRupiah: existing.amountRupiah,
            snapToken: existing.snapToken ?? '',
            snapRedirectUrl: existing.snapRedirectUrl ?? '',
          );
        }
      }
      rethrow;
    }

    final SnapTransaction snap = await midtrans.createSnap(
      orderId: orderId,
      amountRupiah: amount,
      planCode: plan.storageValue,
      businessId: businessId,
    );
    billing.db.transaction<void>((_) {
      billing.payments.updateSnap(
        orderId: orderId,
        snapToken: snap.token,
        snapRedirectUrl: snap.redirectUrl,
        updatedAt: store.clock.nowEpochMs(),
      );
    });
    payment.snapToken = snap.token;
    payment.snapRedirectUrl = snap.redirectUrl;
    payment.updatedAt = store.clock.nowEpochMs();
    store.savePayment(payment);
    store.writeAudit(
      action: 'payment.created',
      entity: 'payment',
      businessId: businessId,
      orderId: orderId,
      detail: 'Checkout ${plan.storageValue} pending. Paket belum aktif.',
    );
    return CheckoutResult(
      orderId: orderId,
      planCode: plan,
      amountRupiah: amount,
      snapToken: snap.token,
      snapRedirectUrl: snap.redirectUrl,
    );
  }
}
