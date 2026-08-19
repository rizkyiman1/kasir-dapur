import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';

/// Sumber tunggal harga backend. Klien tidak boleh menentukan nominal.
final class PlanOffer {
  const PlanOffer({
    required this.plan,
    required this.periodDays,
    this.priceRupiah,
  });

  final BillingPlan plan;
  final int periodDays;
  final int? priceRupiah;
}

final class SubscriptionCatalog {
  const SubscriptionCatalog({
    required this.offers,
    required this.gracePeriodDays,
  });

  final List<PlanOffer> offers;
  final int gracePeriodDays;

  static const String currency = 'IDR';

  factory SubscriptionCatalog.fromPricing(PricingConfig pricing) {
    return SubscriptionCatalog(
      gracePeriodDays: pricing.gracePeriodDays,
      offers: <PlanOffer>[
        const PlanOffer(plan: BillingPlan.free, periodDays: 0, priceRupiah: 0),
        PlanOffer(
          plan: BillingPlan.proMonthly,
          periodDays: BillingPlan.proMonthly.periodDays,
          priceRupiah: pricing.proMonthly,
        ),
        PlanOffer(
          plan: BillingPlan.proYearly,
          periodDays: BillingPlan.proYearly.periodDays,
          priceRupiah: pricing.proYearly,
        ),
        PlanOffer(
          plan: BillingPlan.businessMonthly,
          periodDays: BillingPlan.businessMonthly.periodDays,
          priceRupiah: pricing.businessMonthly,
        ),
        PlanOffer(
          plan: BillingPlan.businessYearly,
          periodDays: BillingPlan.businessYearly.periodDays,
          priceRupiah: pricing.businessYearly,
        ),
      ],
    );
  }

  PlanOffer offerOf(BillingPlan plan) {
    return offers.firstWhere(
      (PlanOffer offer) => offer.plan == plan,
      orElse: () =>
          throw FormatException('Paket ${plan.storageValue} tidak ada.'),
    );
  }

  int requireAmount(BillingPlan plan) {
    if (!plan.isPaid) {
      throw const FormatException('Paket Free tidak ditagih.');
    }
    final int? amount = offerOf(plan).priceRupiah;
    if (amount == null || amount <= 0) {
      throw const FormatException(
        'Harga belum ditetapkan di konfigurasi backend.',
      );
    }
    return amount;
  }

  int? endsAtMs({required BillingPlan plan, required int startsAt}) {
    final int days = offerOf(plan).periodDays;
    if (days <= 0) {
      return null;
    }
    return startsAt + Duration(days: days).inMilliseconds;
  }

  int? graceEndsAtMs({required int endsAt}) {
    if (gracePeriodDays <= 0) {
      return endsAt;
    }
    return endsAt + Duration(days: gracePeriodDays).inMilliseconds;
  }
}

final class FeatureGrant {
  const FeatureGrant({required this.enabled, required this.limit});

  final bool enabled;
  final int limit;

  static const int unlimited = -1;
}

/// Entitlement cloud. Cermin katalog aplikasi, sumber hak setelah bayar.
abstract final class EntitlementCatalog {
  static const int unlimited = FeatureGrant.unlimited;

  static const List<String> keys = <String>[
    'max_businesses',
    'max_products',
    'max_owners',
    'max_cashiers',
    'max_devices',
    'max_branches',
    'offline_pos',
    'basic_inventory',
    'daily_reports',
    'barcode',
    'basic_receipt',
    'multiple_cashiers',
    'advanced_reports',
    'export',
    'customers',
    'suppliers',
    'expenses',
    'profit_analysis',
    'cloud_backup',
    'google_sheets',
    'advanced_printer',
    'dashboard',
    'discount_voucher',
    'multi_branch',
    'multi_device',
    'multi_user',
    'advanced_permission',
    'central_dashboard',
    'cloud_sync',
    'advanced_report',
    'api',
    'advanced_backup',
    'priority_support',
    'business_features',
  ];

  static FeatureGrant grant(PlanFamily family, String key) {
    final bool pro = family == PlanFamily.pro || family == PlanFamily.business;
    final bool business = family == PlanFamily.business;
    switch (key) {
      case 'max_businesses':
      case 'max_branches':
        return FeatureGrant(enabled: true, limit: business ? unlimited : 1);
      case 'max_products':
        return FeatureGrant(
          enabled: true,
          limit: family == PlanFamily.free ? 100 : unlimited,
        );
      case 'max_owners':
        return const FeatureGrant(enabled: true, limit: 1);
      case 'max_cashiers':
        return FeatureGrant(
          enabled: true,
          limit: family == PlanFamily.free ? 1 : unlimited,
        );
      case 'max_devices':
        return FeatureGrant(enabled: true, limit: business ? unlimited : 1);
      case 'offline_pos':
      case 'basic_inventory':
      case 'daily_reports':
      case 'barcode':
      case 'basic_receipt':
        return const FeatureGrant(enabled: true, limit: unlimited);
      case 'multiple_cashiers':
      case 'advanced_reports':
      case 'export':
      case 'customers':
      case 'suppliers':
      case 'expenses':
      case 'profit_analysis':
      case 'cloud_backup':
      case 'google_sheets':
      case 'advanced_printer':
      case 'dashboard':
      case 'discount_voucher':
        return FeatureGrant(enabled: pro, limit: pro ? unlimited : 0);
      default:
        return FeatureGrant(enabled: business, limit: business ? unlimited : 0);
    }
  }
}
