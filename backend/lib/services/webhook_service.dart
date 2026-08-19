import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/billing/billing_state.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/catalog.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/domain/status.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_signature.dart';

final class WebhookResult {
  const WebhookResult({
    required this.ok,
    required this.duplicate,
    required this.activated,
    required this.status,
    this.orderId,
  });

  final bool ok;
  final bool duplicate;
  final bool activated;
  final String status;
  final String? orderId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'ok': ok,
      'duplicate': duplicate,
      'activated': activated,
      'status': status,
      'order_id': orderId,
    };
  }
}

final class SignatureException implements Exception {
  const SignatureException([this.message = 'Tanda tangan Midtrans tidak sah.']);

  final String message;
}

final class WebhookService {
  WebhookService({
    required this.store,
    required this.catalog,
    required this.midtrans,
    required this.midtransConfig,
    required this.billing,
  });

  final AppStore store;
  final SubscriptionCatalog catalog;
  final MidtransGateway midtrans;
  final MidtransConfig midtransConfig;
  final BillingState billing;

  Future<WebhookResult> handle(Map<String, Object?> body) async {
    final String orderId = _string(body, 'order_id');
    final String statusCode = _string(body, 'status_code');
    final String grossAmount = _string(body, 'gross_amount');
    final String signature = _string(body, 'signature_key');
    final String transactionStatusRaw = _string(body, 'transaction_status');
    final String transactionId = _string(
      body,
      'transaction_id',
      optional: true,
    );
    final String merchantId = _string(body, 'merchant_id', optional: true);

    if (!MidtransSignature.matches(
      orderId: orderId,
      statusCode: statusCode,
      grossAmount: grossAmount,
      serverKey: midtransConfig.serverKey,
      provided: signature,
    )) {
      store.writeAudit(
        action: 'webhook.rejected',
        entity: 'webhook',
        orderId: orderId,
        detail: 'Signature tidak sah. Langganan tidak diubah.',
      );
      throw const SignatureException();
    }

    if (midtransConfig.merchantId.isNotEmpty &&
        merchantId.isNotEmpty &&
        merchantId != midtransConfig.merchantId) {
      throw const FormatException('Merchant ID tidak cocok.');
    }

    final String fingerprint =
        '$orderId|$transactionStatusRaw|$statusCode|$transactionId';
    final MidtransTransactionStatus status = MidtransTransactionStatus.parse(
      transactionStatusRaw,
    );

    final MidtransStatusSnapshot remote = await midtrans.fetchStatus(orderId);
    if (remote.transactionStatus != status.storageValue) {
      store.writeAudit(
        action: 'webhook.status_mismatch',
        entity: 'payment',
        orderId: orderId,
        detail: 'Status webhook tidak sama dengan Get Status Midtrans.',
      );
      throw const FormatException(
        'Verifikasi status Midtrans gagal. Paket belum diaktifkan.',
      );
    }
    final int now = store.clock.nowEpochMs();
    return billing.db.transactionAsync<WebhookResult>((_) async {
      final String claimId = store.nextId();
      final bool claimed = billing.webhooks.tryClaimFingerprint(
        id: claimId,
        fingerprint: fingerprint,
        orderId: orderId,
        processedAt: now,
        providerStatus: status.storageValue,
      );
      if (!claimed) {
        store.rememberWebhook(fingerprint);
        return WebhookResult(
          ok: true,
          duplicate: true,
          activated: false,
          status: status.storageValue,
          orderId: orderId,
        );
      }

      final PaymentRecord? payment = billing.payments.findByOrderId(orderId);
      if (payment == null) {
        billing.webhooks.recordProcessed(
          id: claimId,
          fingerprint: fingerprint,
          orderId: orderId,
          processedAt: now,
          resultStatus: 'unmatched',
          providerStatus: status.storageValue,
        );
        billing.audit.append(
          id: store.nextId(),
          eventType: 'webhook_received',
          orderId: orderId,
          detail: 'Order tidak dikenal.',
          createdAt: now,
        );
        store.rememberWebhook(fingerprint);
        return WebhookResult(
          ok: true,
          duplicate: false,
          activated: false,
          status: status.storageValue,
          orderId: orderId,
        );
      }

      final String expectedGross = MidtransSignature.grossAmountOf(
        payment.amountRupiah,
      );
      if (grossAmount != expectedGross &&
          grossAmount != '${payment.amountRupiah}') {
        throw const FormatException('Nominal pembayaran tidak cocok.');
      }

      if (payment.state == CloudPaymentState.verified) {
        billing.webhooks.recordProcessed(
          id: claimId,
          fingerprint: fingerprint,
          orderId: orderId,
          processedAt: now,
          resultStatus: 'already_verified',
          providerStatus: status.storageValue,
        );
        store.rememberWebhook(fingerprint);
        return WebhookResult(
          ok: true,
          duplicate: true,
          activated: false,
          status: status.storageValue,
          orderId: orderId,
        );
      }

      payment.midtransStatus = status;
      payment.updatedAt = store.clock.nowEpochMs();
      if (status.isSuccess) {
        billing.activatePaid(
          payment: payment,
          catalog: catalog,
          verifiedAt: payment.updatedAt,
        );
        billing.webhooks.recordProcessed(
          id: claimId,
          fingerprint: fingerprint,
          orderId: orderId,
          processedAt: payment.updatedAt,
          resultStatus: 'activated',
          providerStatus: status.storageValue,
        );
        billing.audit.append(
          id: store.nextId(),
          eventType: 'payment_verified',
          businessId: payment.businessId,
          orderId: payment.orderId,
          detail: 'Payment verified via webhook.',
          createdAt: payment.updatedAt,
        );
        store.rememberWebhook(fingerprint);
        return WebhookResult(
          ok: true,
          duplicate: false,
          activated: true,
          status: status.storageValue,
          orderId: orderId,
        );
      }

      if (status.isTerminalFailure) {
        payment.state = paymentStateFromMidtrans(status);
        billing.payments.update(
          payment,
          failureReason: 'webhook_${status.storageValue}',
        );
        billing.webhooks.recordProcessed(
          id: claimId,
          fingerprint: fingerprint,
          orderId: orderId,
          processedAt: payment.updatedAt,
          resultStatus: 'failed',
          providerStatus: status.storageValue,
        );
        store.savePayment(payment);
        store.rememberWebhook(fingerprint);
        return WebhookResult(
          ok: true,
          duplicate: false,
          activated: false,
          status: status.storageValue,
          orderId: orderId,
        );
      }

      billing.payments.update(payment);
      billing.webhooks.recordProcessed(
        id: claimId,
        fingerprint: fingerprint,
        orderId: orderId,
        processedAt: payment.updatedAt,
        resultStatus: 'pending',
        providerStatus: status.storageValue,
      );
      store.savePayment(payment);
      store.rememberWebhook(fingerprint);
      return WebhookResult(
        ok: true,
        duplicate: false,
        activated: false,
        status: status.storageValue,
        orderId: orderId,
      );
    });
  }

  String _string(
    Map<String, Object?> body,
    String key, {
    bool optional = false,
  }) {
    final Object? value = body[key];
    if (value is String && value.isNotEmpty) {
      return value;
    }
    if (optional) {
      return '';
    }
    throw FormatException('Kolom $key wajib pada notifikasi Midtrans.');
  }
}
