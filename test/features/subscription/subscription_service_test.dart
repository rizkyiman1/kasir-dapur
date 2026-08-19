import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/subscription/data/memory_billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/data/subscription_repository_impl.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_status.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late AdjustableClock clock;
  late SqliteSubscriptionRepository store;
  late MemoryBillingGateway billing;
  late String businessId;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_plan_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    clock = AdjustableClock(DateTime.utc(2026, 8, 18, 8));
    store = SqliteSubscriptionRepository(database: database, clock: clock);
    billing = MemoryBillingGateway();
    businessId = await insertBusiness(await database.database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  SubscriptionService service({
    required AuthUser user,
    SubscriptionConfig config = SubscriptionConfig.standard,
  }) {
    return SubscriptionService(
      store: store,
      entitlements: store,
      payments: store,
      billing: billing,
      config: config,
      clock: clock,
      guard: PermissionGuard(),
      access: () => StaticAccessContext(currentUser: user),
    );
  }

  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );
  const AuthUser cashier = AuthUser(
    id: 'c1',
    displayName: 'Cici',
    role: UserRole.cashier,
  );

  const SubscriptionConfig priced = SubscriptionConfig(
    gracePeriodDays: 7,
    offers: <PlanOffer>[
      PlanOffer(planCode: BillingPlan.free, periodDays: 0, priceRupiah: 0),
      PlanOffer(
        planCode: BillingPlan.proMonthly,
        periodDays: 30,
        priceRupiah: 150000,
      ),
      PlanOffer(
        planCode: BillingPlan.proYearly,
        periodDays: 365,
        priceRupiah: 1500000,
      ),
      PlanOffer(
        planCode: BillingPlan.businessMonthly,
        periodDays: 30,
        priceRupiah: 350000,
      ),
      PlanOffer(
        planCode: BillingPlan.businessYearly,
        periodDays: 365,
        priceRupiah: 3500000,
      ),
    ],
  );

  test('ensureDefault menulis paket Free dan entitlement SQLite', () async {
    final SubscriptionService svc = service(user: owner);
    final Subscription current = await svc.ensureDefault(businessId);
    expect(current.plan, Plan.free);
    expect(current.planCode, BillingPlan.free);
    expect(current.status, SubscriptionStatus.active);
    final FeatureGate gate = await svc.gate(businessId);
    expect(gate.canUse(FeatureKey.offlinePos), isTrue);
    expect(gate.canUse(FeatureKey.googleSheetsSync), isFalse);
    expect(gate.limitOf(FeatureKey.maxProducts), 100);
    expect(
      (await store.find(
        businessId: businessId,
        key: FeatureKey.cloudBackup,
      ))?.isEnabled,
      isFalse,
    );
  });

  test('tombol pembayaran tidak mengaktifkan paket', () async {
    final SubscriptionService svc = service(user: owner, config: priced);
    await svc.ensureDefault(businessId);
    final UpgradeRequestResult result = await svc.requestUpgrade(
      businessId: businessId,
      planCode: BillingPlan.proMonthly,
    );
    expect(result.pending.status, SubscriptionStatus.pending);
    expect(result.payment.status, PaymentStatus.pending);
    expect(result.payment.amountRupiah, 150000);
    expect(result.checkout, isNotNull);
    final FeatureGate gate = await svc.gate(businessId);
    expect(gate.plan, Plan.free);
    expect(gate.canUse(FeatureKey.googleSheetsSync), isFalse);
    final Subscription current = await svc.currentPlan(businessId);
    expect(current.plan, Plan.free);
    expect(current.status, SubscriptionStatus.active);
    expect((await svc.paymentHistory(businessId)), hasLength(1));
  });

  test('verifikasi backend mengaktifkan Pro dan menulis expiry', () async {
    final SubscriptionService svc = service(user: owner, config: priced);
    await svc.ensureDefault(businessId);
    final UpgradeRequestResult result = await svc.requestUpgrade(
      businessId: businessId,
      planCode: BillingPlan.proMonthly,
    );
    final int startsAt = clock.nowEpochMs();
    billing.confirmFromBackend(
      businessId: businessId,
      orderId: result.checkout!.orderId,
      startsAt: startsAt,
      verifiedAt: startsAt,
      endsAt: priced.endsAtMs(
        planCode: BillingPlan.proMonthly,
        startsAt: startsAt,
      ),
      graceEndsAt: priced.graceEndsAtMs(
        endsAt: priced.endsAtMs(
          planCode: BillingPlan.proMonthly,
          startsAt: startsAt,
        )!,
      ),
    );
    final Subscription active = await svc.syncFromBackend(businessId);
    expect(active.plan, Plan.pro);
    expect(active.planCode, BillingPlan.proMonthly);
    expect(active.status, SubscriptionStatus.active);
    expect(active.verifiedAt, isNotNull);
    expect(active.endsAt, isNotNull);
    final FeatureGate gate = await svc.gate(businessId);
    expect(gate.canUse(FeatureKey.googleSheetsSync), isTrue);
    expect(gate.canUse(FeatureKey.export), isTrue);
    expect(gate.canUse(FeatureKey.multiBranch), isFalse);
    expect(
      (await svc.paymentHistory(businessId)).first.status,
      PaymentStatus.verified,
    );
  });

  test('masa tenggang tetap Pro, kedaluwarsa kembali ke Free', () async {
    final SubscriptionService svc = service(user: owner);
    await svc.ensureDefault(businessId);
    final int startsAt = clock.nowEpochMs();
    await svc.applyVerifiedEntitlement(
      VerifiedSubscription(
        businessId: businessId,
        planCode: BillingPlan.proMonthly,
        status: SubscriptionStatus.active,
        startsAt: startsAt,
        endsAt: startsAt + const Duration(hours: 1).inMilliseconds,
        graceEndsAt: startsAt + const Duration(hours: 3).inMilliseconds,
        verifiedAt: startsAt,
        orderId: 'order-expiry',
      ),
    );
    expect((await svc.gate(businessId)).canUse(FeatureKey.export), isTrue);

    clock.advance(const Duration(hours: 2));
    expect((await svc.gate(businessId)).plan, Plan.pro);
    expect(
      (await svc.currentPlan(businessId)).status,
      SubscriptionStatus.gracePeriod,
    );
    expect((await svc.gate(businessId)).canUse(FeatureKey.export), isTrue);

    clock.advance(const Duration(hours: 2));
    final FeatureGate expired = await svc.gate(businessId);
    expect(expired.plan, Plan.free);
    expect(expired.canUse(FeatureKey.export), isFalse);
    expect((await svc.currentPlan(businessId)).planCode, BillingPlan.free);
  });

  test('restore entitlement menulis ulang dari paket terverifikasi', () async {
    final SubscriptionService svc = service(user: owner);
    await svc.ensureDefault(businessId);
    await svc.applyVerifiedEntitlement(
      VerifiedSubscription(
        businessId: businessId,
        planCode: BillingPlan.businessYearly,
        status: SubscriptionStatus.active,
        startsAt: clock.nowEpochMs(),
        verifiedAt: clock.nowEpochMs(),
        orderId: 'order-restore',
      ),
    );
    await (await database.database).delete(DatabaseConstants.tableEntitlements);
    expect((await store.list(businessId)), isEmpty);
    await svc.restoreEntitlements(businessId);
    expect(
      (await store.find(
        businessId: businessId,
        key: FeatureKey.multiBranch,
      ))?.isEnabled,
      isTrue,
    );
    expect((await svc.gate(businessId)).plan, Plan.business);
  });

  test('kasir tidak boleh mengajukan upgrade', () async {
    final SubscriptionService svc = service(user: cashier);
    await svc.ensureDefault(businessId);
    expect(
      () => svc.requestUpgrade(
        businessId: businessId,
        planCode: BillingPlan.proMonthly,
      ),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
