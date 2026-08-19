import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_status.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_payment.dart';

abstract class PaymentHistoryRepository {
  Future<SubscriptionPayment> insertPayment({
    required String businessId,
    String? subscriptionId,
    required BillingPlan planCode,
    required int amountRupiah,
    required String currency,
    required PaymentStatus status,
    required String provider,
    required String clientUuid,
    String? providerOrderId,
    String? snapToken,
    String? snapRedirectUrl,
    String? failureReason,
  });

  Future<List<SubscriptionPayment>> listPayments(String businessId);

  Future<SubscriptionPayment?> findPaymentByClientUuid(String clientUuid);

  Future<SubscriptionPayment?> findPaymentByOrderId(String orderId);

  Future<SubscriptionPayment> updatePayment({
    required String id,
    PaymentStatus? status,
    String? subscriptionId,
    String? providerOrderId,
    String? snapToken,
    String? snapRedirectUrl,
    int? verifiedAt,
    String? failureReason,
  });
}
