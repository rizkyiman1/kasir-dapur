import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_status.dart';

final class SubscriptionPayment {
  const SubscriptionPayment({
    required this.id,
    required this.businessId,
    this.subscriptionId,
    required this.planCode,
    required this.amountRupiah,
    required this.currency,
    required this.status,
    required this.provider,
    required this.clientUuid,
    this.providerOrderId,
    this.snapToken,
    this.snapRedirectUrl,
    this.verifiedAt,
    this.failureReason,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String? subscriptionId;
  final BillingPlan planCode;
  final int amountRupiah;
  final String currency;
  final PaymentStatus status;
  final String provider;
  final String clientUuid;
  final String? providerOrderId;
  final String? snapToken;
  final String? snapRedirectUrl;
  final int? verifiedAt;
  final String? failureReason;
  final int createdAt;
  final int updatedAt;

  bool get isVerified => status == PaymentStatus.verified;
}
