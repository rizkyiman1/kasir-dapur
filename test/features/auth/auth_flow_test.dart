import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/result/result.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/auth/domain/auth_state.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/domain/session.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late AdjustableClock clock;
  late ProviderContainer container;
  late AuthController auth;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_flow_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    clock = AdjustableClock(DateTime.utc(2026, 8, 18, 8));
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        clockProvider.overrideWithValue(clock),
        sessionConfigProvider.overrideWithValue(
          const SessionConfig(
            idleLock: Duration(minutes: 5),
            maxDuration: Duration(hours: 12),
            checkInterval: Duration(days: 1),
            touchDebounce: Duration.zero,
          ),
        ),
      ],
    );
    auth = container.read(authControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> onboardOwner() async {
    final Result<void> result = await auth.completeOnboarding(
      displayName: 'Budi',
      pin: '123456',
    );
    expect(result.isSuccess, isTrue);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
    expect(container.read(authControllerProvider).user!.role, UserRole.owner);
  }

  test('login invalid ditolak', () async {
    await onboardOwner();
    await auth.logout();
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );

    final Result<void> failed = await auth.login(pin: '654321');
    expect(failed.isFailure, isTrue);
    expect(failed, isA<Failure<void>>());
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );

    final Result<void> ok = await auth.login(pin: '123456');
    expect(ok.isSuccess, isTrue);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });

  test('logout menghapus sesi', () async {
    await onboardOwner();
    expect(
      await container.read(sessionRepositoryProvider).current(),
      isNotNull,
    );
    await auth.logout();
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(await container.read(sessionRepositoryProvider).current(), isNull);
  });

  test('kunci layar dan buka dengan PIN', () async {
    await onboardOwner();
    await auth.lock();
    expect(container.read(authControllerProvider).status, AuthStatus.locked);
    expect(container.read(authControllerProvider).user!.displayName, 'Budi');

    final Result<void> bad = await auth.unlock('654321');
    expect(bad.isFailure, isTrue);
    expect(container.read(authControllerProvider).status, AuthStatus.locked);

    final Result<void> ok = await auth.unlock('123456');
    expect(ok.isSuccess, isTrue);
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.authenticated,
    );
  });

  test('idle timeout mengunci, durasi maksimum mengakhiri sesi', () async {
    await onboardOwner();
    clock.advance(const Duration(minutes: 5));
    await auth.checkSession();
    expect(container.read(authControllerProvider).status, AuthStatus.locked);

    final Result<void> unlocked = await auth.unlock('123456');
    expect(unlocked.isSuccess, isTrue);

    clock.advance(const Duration(hours: 12));
    await auth.checkSession();
    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(await container.read(sessionRepositoryProvider).current(), isNull);
  });

  test('admin dan kasir bisa masuk, kasir tidak boleh kelola user', () async {
    await onboardOwner();
    final String businessId = await container.read(
      activeBusinessIdProvider.future,
    );
    await container
        .read(subscriptionServiceProvider)
        .applyVerifiedEntitlement(
          VerifiedSubscription(
            businessId: businessId,
            planCode: BillingPlan.businessMonthly,
            status: SubscriptionStatus.active,
            startsAt: clock.nowEpochMs(),
            verifiedAt: clock.nowEpochMs(),
            orderId: 'auth-flow-order',
          ),
        );
    container.invalidate(featureGateProvider);
    final Result<AuthUser> adminResult = await auth.createUser(
      displayName: 'Ani',
      pin: '234567',
      role: UserRole.admin,
    );
    final Result<AuthUser> cashierResult = await auth.createUser(
      displayName: 'Cici',
      pin: '345678',
      role: UserRole.cashier,
    );
    expect(adminResult.isSuccess, isTrue);
    expect(cashierResult.isSuccess, isTrue);
    final AuthUser adminUser = adminResult.getOrThrow();
    final AuthUser cashierUser = cashierResult.getOrThrow();

    await auth.logout();
    expect(
      (await auth.login(pin: '234567', userId: adminUser.id)).isSuccess,
      isTrue,
    );
    expect(container.read(authControllerProvider).user!.role, UserRole.admin);
    final Result<AuthUser> denied = await auth.createUser(
      displayName: 'Dedi',
      pin: '456789',
      role: UserRole.cashier,
    );
    expect(denied.isFailure, isTrue);
    expect(denied, isA<Failure<AuthUser>>());
    expect((denied as Failure<AuthUser>).error, isA<ForbiddenException>());

    await auth.logout();
    expect(
      (await auth.login(pin: '345678', userId: cashierUser.id)).isSuccess,
      isTrue,
    );
    expect(container.read(authControllerProvider).user!.role, UserRole.cashier);
  });
}
