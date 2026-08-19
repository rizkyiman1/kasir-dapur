import 'package:kasir_dapur/features/subscription/domain/billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:uuid/uuid.dart';

/// Gateway tes/lokal. Tidak pernah mengaktifkan paket; webhook disimulasikan terpisah.
final class MemoryBillingGateway implements BillingGateway {
  MemoryBillingGateway({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;
  final Map<String, CheckoutSession> _checkouts = <String, CheckoutSession>{};
  final Map<String, VerifiedSubscription> _verified =
      <String, VerifiedSubscription>{};

  Iterable<CheckoutSession> get checkouts => _checkouts.values;

  @override
  Future<CheckoutSession> createCheckout(CheckoutRequest request) async {
    final int? amount = SubscriptionConfig.standard.amountRupiah(
      request.planCode,
    );
    final CheckoutSession session = CheckoutSession(
      orderId: 'order-${_uuid.v4()}',
      planCode: request.planCode,
      amountRupiah: amount ?? 0,
      snapToken: 'snap-token-placeholder',
      snapRedirectUrl:
          'https://app.sandbox.midtrans.com/snap/v2/vtweb/${request.clientUuid}',
    );
    _checkouts[session.orderId] = session;
    return session;
  }

  @override
  Future<VerifiedSubscription?> fetchVerified(String businessId) async {
    return _verified[businessId];
  }

  /// Simulasi webhook backend setelah Midtrans notify. Bukan tombol di aplikasi.
  void confirmFromBackend({
    required String businessId,
    required String orderId,
    required int startsAt,
    required int verifiedAt,
    SubscriptionStatus status = SubscriptionStatus.active,
    int? endsAt,
    int? graceEndsAt,
  }) {
    final CheckoutSession? session = _checkouts[orderId];
    final BillingPlan planCode = session?.planCode ?? BillingPlan.proMonthly;
    _verified[businessId] = VerifiedSubscription(
      businessId: businessId,
      planCode: planCode,
      status: status,
      startsAt: startsAt,
      endsAt: endsAt,
      graceEndsAt: graceEndsAt,
      verifiedAt: verifiedAt,
      orderId: orderId,
      provider: SubscriptionConfig.providerMidtrans,
    );
  }
}
