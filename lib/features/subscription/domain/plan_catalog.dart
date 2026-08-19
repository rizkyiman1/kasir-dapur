import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';

final class FeatureGrant {
  const FeatureGrant({required this.enabled, required this.limit});

  final bool enabled;

  /// -1 = tak terbatas. 0 = tidak tersedia.
  final int limit;

  static const int unlimited = -1;
}

/// Sumber tunggal: paket → entitlement. Bukan if di layar.
abstract final class PlanCatalog {
  static const int unlimited = FeatureGrant.unlimited;

  static FeatureGrant grant(Plan plan, FeatureKey key) {
    final bool pro = plan == Plan.pro || plan == Plan.business;
    final bool business = plan == Plan.business;
    return switch (key) {
      FeatureKey.maxBusinesses || FeatureKey.maxBranches => FeatureGrant(
        enabled: true,
        limit: business ? unlimited : 1,
      ),
      FeatureKey.maxProducts => FeatureGrant(
        enabled: true,
        limit: plan == Plan.free ? 100 : unlimited,
      ),
      FeatureKey.maxOwners => const FeatureGrant(enabled: true, limit: 1),
      FeatureKey.maxCashiers => FeatureGrant(
        enabled: true,
        limit: plan == Plan.free ? 1 : unlimited,
      ),
      FeatureKey.maxDevices => FeatureGrant(
        enabled: true,
        limit: business ? unlimited : 1,
      ),
      FeatureKey.offlinePos ||
      FeatureKey.basicInventory ||
      FeatureKey.dailyReports ||
      FeatureKey.barcode ||
      FeatureKey.basicReceipt => const FeatureGrant(
        enabled: true,
        limit: unlimited,
      ),
      FeatureKey.multipleCashiers ||
      FeatureKey.advancedReports ||
      FeatureKey.export ||
      FeatureKey.customers ||
      FeatureKey.suppliers ||
      FeatureKey.expenses ||
      FeatureKey.profitAnalysis ||
      FeatureKey.cloudBackup ||
      FeatureKey.googleSheetsSync ||
      FeatureKey.advancedPrinter ||
      FeatureKey.dashboard ||
      FeatureKey.discountVoucher => FeatureGrant(
        enabled: pro,
        limit: pro ? unlimited : 0,
      ),
      FeatureKey.multiBranch ||
      FeatureKey.multiDevice ||
      FeatureKey.multiUser ||
      FeatureKey.advancedPermission ||
      FeatureKey.centralDashboard ||
      FeatureKey.cloudSync ||
      FeatureKey.advancedReport ||
      FeatureKey.apiAccess ||
      FeatureKey.advancedBackup ||
      FeatureKey.prioritySupport ||
      FeatureKey.businessFeatures => FeatureGrant(
        enabled: business,
        limit: business ? unlimited : 0,
      ),
    };
  }

  static Plan minimumFor(FeatureKey key) {
    for (final Plan plan in Plan.values) {
      if (grant(plan, key).enabled) {
        return plan;
      }
    }
    return Plan.business;
  }

  static String formatLimit(int limit) {
    if (limit < 0) {
      return 'Tak terbatas';
    }
    if (limit == 0) {
      return '—';
    }
    return '$limit';
  }

  static String cell(Plan plan, FeatureKey key) {
    final FeatureGrant value = grant(plan, key);
    if (key.isLimit) {
      return formatLimit(value.limit);
    }
    return value.enabled ? 'Ya' : '—';
  }
}
