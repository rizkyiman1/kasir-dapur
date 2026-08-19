import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_catalog.dart';

void main() {
  test('FeatureGate.canUse Google Sheets hanya Pro/Business', () {
    final FeatureGate free = FeatureGate.forPlan(Plan.free);
    final FeatureGate pro = FeatureGate.forPlan(Plan.pro);
    final FeatureGate business = FeatureGate.forPlan(Plan.business);

    expect(free.canUse(FeatureKey.googleSheetsSync), isFalse);
    expect(pro.canUse(FeatureKey.googleSheetsSync), isTrue);
    expect(business.canUse(FeatureKey.googleSheetsSync), isTrue);
    expect(free.canUse(FeatureKey.offlinePos), isTrue);
    expect(free.canUse(FeatureKey.customers), isFalse);
    expect(pro.canUse(FeatureKey.customers), isTrue);
    expect(pro.canUse(FeatureKey.multiBranch), isFalse);
    expect(business.canUse(FeatureKey.multiBranch), isTrue);
    expect(business.canUse(FeatureKey.apiAccess), isTrue);
  });

  test('batas produk dan kasir integer, tanpa pecahan', () {
    final FeatureGate free = FeatureGate.forPlan(Plan.free);
    expect(free.limitOf(FeatureKey.maxProducts), 100);
    expect(free.isWithinLimit(FeatureKey.maxProducts, 99), isTrue);
    expect(free.isWithinLimit(FeatureKey.maxProducts, 100), isFalse);
    expect(free.limitOf(FeatureKey.maxCashiers), 1);
    expect(free.isWithinLimit(FeatureKey.maxCashiers, 0), isTrue);
    expect(free.isWithinLimit(FeatureKey.maxCashiers, 1), isFalse);

    final FeatureGate pro = FeatureGate.forPlan(Plan.pro);
    expect(pro.limitOf(FeatureKey.maxProducts), PlanCatalog.unlimited);
    expect(pro.isWithinLimit(FeatureKey.maxProducts, 10000), isTrue);
  });

  test('require menolak fitur berbayar di Free', () {
    final FeatureGate free = FeatureGate.forPlan(Plan.free);
    expect(
      () => free.require(FeatureKey.export),
      throwsA(isA<PlanLimitException>()),
    );
    expect(
      () => free.requireWithinLimit(FeatureKey.maxCashiers, 1),
      throwsA(isA<PlanLimitException>()),
    );
  });
}
