import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/money/money.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';

/// Satu penawaran SKU. Harga hanya di sini, bukan di layar atau layanan.
final class PlanOffer {
  const PlanOffer({
    required this.planCode,
    required this.periodDays,
    this.priceRupiah,
  });

  final BillingPlan planCode;
  final int periodDays;

  /// Integer Rupiah. Null = belum ditetapkan di konfigurasi bisnis.
  final int? priceRupiah;

  Plan get family => planCode.family;

  BillingCycle get cycle => planCode.cycle;

  bool get isPricePublished =>
      planCode == BillingPlan.free || priceRupiah != null;

  String get priceLabel {
    if (planCode == BillingPlan.free) {
      return 'Gratis';
    }
    final int? amount = priceRupiah;
    if (amount == null) {
      return 'Harga: menyusul konfigurasi bisnis';
    }
    return Money(amount).formatId();
  }

  String get cycleLabel {
    return switch (cycle) {
      BillingCycle.none => 'Tanpa periode',
      BillingCycle.monthly => 'Bulanan',
      BillingCycle.yearly => 'Tahunan',
    };
  }

  int? endsAtMs(int startsAt) {
    if (periodDays <= 0) {
      return null;
    }
    return startsAt + Duration(days: periodDays).inMilliseconds;
  }
}

/// Sumber tunggal harga, masa berlaku, dan masa tenggang.
final class SubscriptionConfig {
  const SubscriptionConfig({
    required this.offers,
    required this.gracePeriodDays,
  });

  final List<PlanOffer> offers;
  final int gracePeriodDays;

  static const String currency = 'IDR';
  static const String providerMidtrans = 'midtrans';
  static const String providerBackend = 'backend';
  static const String providerDefault = 'default';

  /// Jalur API milik backend Kasir Dapur, bukan Midtrans Server API.
  static const String checkoutPath = '/v1/billing/checkout';
  static const String currentPath = '/v1/billing/subscription';
  static const String paymentsPath = '/v1/billing/payments';

  /// Harga komersial final. Checkout tetap authority dari backend.
  static const SubscriptionConfig standard = SubscriptionConfig(
    gracePeriodDays: 7,
    offers: <PlanOffer>[
      PlanOffer(planCode: BillingPlan.free, periodDays: 0, priceRupiah: 0),
      PlanOffer(
        planCode: BillingPlan.proMonthly,
        periodDays: 30,
        priceRupiah: 49000,
      ),
      PlanOffer(
        planCode: BillingPlan.proYearly,
        periodDays: 365,
        priceRupiah: 490000,
      ),
      PlanOffer(
        planCode: BillingPlan.businessMonthly,
        periodDays: 30,
        priceRupiah: 99000,
      ),
      PlanOffer(
        planCode: BillingPlan.businessYearly,
        periodDays: 365,
        priceRupiah: 990000,
      ),
    ],
  );

  PlanOffer offerOf(BillingPlan planCode) {
    for (final PlanOffer offer in offers) {
      if (offer.planCode == planCode) {
        return offer;
      }
    }
    throw ValidationException(
      'Konfigurasi paket ${planCode.storageValue} tidak ada.',
    );
  }

  String priceLabel(BillingPlan planCode) => offerOf(planCode).priceLabel;

  int? amountRupiah(BillingPlan planCode) => offerOf(planCode).priceRupiah;

  int? endsAtMs({required BillingPlan planCode, required int startsAt}) {
    return offerOf(planCode).endsAtMs(startsAt);
  }

  int? graceEndsAtMs({required int endsAt}) {
    if (gracePeriodDays <= 0) {
      return endsAt;
    }
    return endsAt + Duration(days: gracePeriodDays).inMilliseconds;
  }

  Iterable<PlanOffer> get paidOffers {
    return offers.where((PlanOffer offer) => offer.planCode.isPaid);
  }
}
