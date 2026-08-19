import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';

/// Sesi checkout dari backend Kasir Dapur. Bukan Server Key Midtrans.
final class CheckoutSession {
  const CheckoutSession({
    required this.orderId,
    required this.planCode,
    required this.amountRupiah,
    this.snapToken,
    this.snapRedirectUrl,
  });

  final String orderId;
  final BillingPlan planCode;
  final int amountRupiah;
  final String? snapToken;
  final String? snapRedirectUrl;
}

/// Hasil verifikasi server. Satu-satunya izin mengaktifkan paket berbayar.
final class VerifiedSubscription {
  const VerifiedSubscription({
    required this.businessId,
    required this.planCode,
    required this.status,
    required this.startsAt,
    this.endsAt,
    this.graceEndsAt,
    required this.verifiedAt,
    required this.orderId,
    this.provider = 'midtrans',
  });

  final String businessId;
  final BillingPlan planCode;
  final SubscriptionStatus status;
  final int startsAt;
  final int? endsAt;
  final int? graceEndsAt;
  final int verifiedAt;
  final String orderId;
  final String provider;

  bool get grantsEntitlements => status.grantsEntitlements;
}

final class CheckoutRequest {
  const CheckoutRequest({
    required this.businessId,
    required this.planCode,
    required this.clientUuid,
  });

  final String businessId;
  final BillingPlan planCode;
  final String clientUuid;
}

/// Port pembayaran. Klien memanggil backend sendiri, tidak ke Midtrans Server.
abstract class BillingGateway {
  Future<CheckoutSession> createCheckout(CheckoutRequest request);

  Future<VerifiedSubscription?> fetchVerified(String businessId);
}
