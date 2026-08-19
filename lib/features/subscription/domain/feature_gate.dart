import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_catalog.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';

/// Pintu fitur. Layar memanggil [canUse], bukan membandingkan nama paket.
final class FeatureGate {
  FeatureGate({required this.plan, required Map<FeatureKey, Entitlement> byKey})
    : _byKey = Map<FeatureKey, Entitlement>.unmodifiable(byKey);

  factory FeatureGate.forPlan(Plan plan) {
    return FeatureGate(
      plan: plan,
      byKey: <FeatureKey, Entitlement>{
        for (final FeatureKey key in FeatureKey.values)
          key: Entitlement(
            id: key.storageValue,
            businessId: '',
            featureKey: key.storageValue,
            isEnabled: PlanCatalog.grant(plan, key).enabled,
            limitValue: PlanCatalog.grant(plan, key).limit,
          ),
      },
    );
  }

  factory FeatureGate.fromEntitlements(
    Iterable<Entitlement> rows, {
    required Plan plan,
  }) {
    final List<Entitlement> list = rows.toList();
    if (list.isEmpty) {
      return FeatureGate.forPlan(plan);
    }
    final Map<FeatureKey, Entitlement> byKey = <FeatureKey, Entitlement>{};
    for (final Entitlement row in list) {
      try {
        byKey[row.key] = row;
      } on PlanLimitException {
        continue;
      } on ValidationException {
        continue;
      }
    }
    if (byKey.isEmpty) {
      return FeatureGate.forPlan(plan);
    }
    return FeatureGate(plan: plan, byKey: byKey);
  }

  final Plan plan;
  final Map<FeatureKey, Entitlement> _byKey;

  bool canUse(FeatureKey key) {
    final Entitlement? row = _byKey[key];
    if (row != null) {
      return row.isEnabled;
    }
    return PlanCatalog.grant(plan, key).enabled;
  }

  bool canUseAny(Iterable<FeatureKey> keys) {
    for (final FeatureKey key in keys) {
      if (canUse(key)) {
        return true;
      }
    }
    return false;
  }

  int limitOf(FeatureKey key) {
    final Entitlement? row = _byKey[key];
    if (row != null) {
      return row.limitValue;
    }
    return PlanCatalog.grant(plan, key).limit;
  }

  bool isUnlimited(FeatureKey key) => limitOf(key) < 0;

  bool isWithinLimit(FeatureKey key, int used) {
    final int limit = limitOf(key);
    if (limit == 0 && !canUse(key)) {
      return false;
    }
    if (limit < 0) {
      return true;
    }
    return used < limit;
  }

  String denyMessage(FeatureKey key) {
    final Plan minimum = PlanCatalog.minimumFor(key);
    if (key.isLimit) {
      final String cap = PlanCatalog.formatLimit(limitOf(key));
      return 'Paket ${plan.label} membatasi ${key.label} hingga $cap. Naikkan paket untuk menambah kuota. Harga belum ditetapkan.';
    }
    if (minimum.rank > plan.rank) {
      return '${key.label} tersedia mulai paket ${minimum.label}. Harga belum ditetapkan.';
    }
    return '${key.label} tidak aktif pada paket ${plan.label}.';
  }

  void require(FeatureKey key) {
    if (!canUse(key)) {
      throw PlanLimitException(denyMessage(key), featureKey: key.storageValue);
    }
  }

  void requireWithinLimit(FeatureKey key, int used) {
    if (!isWithinLimit(key, used)) {
      throw PlanLimitException(denyMessage(key), featureKey: key.storageValue);
    }
  }
}
