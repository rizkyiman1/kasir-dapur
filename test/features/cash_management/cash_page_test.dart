import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash_repository.dart';
import 'package:kasir_dapur/features/cash_management/presentation/cash_management_page.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('open cashier, expected cash, dan close cashier', (tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const CashSession session = CashSession(
      id: 'ses-1',
      businessId: 'biz-1',
      openingAmount: 100000,
      status: CashSessionStatus.open,
      openedAt: 1,
      createdAt: 1,
      updatedAt: 1,
    );
    final _FakeCashRepository repo = _FakeCashRepository(open: session);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => SeededAuthController(user: owner),
          ),
          activeBusinessIdProvider.overrideWith((Ref ref) async => 'biz-1'),
          cashRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CashManagementPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Opening balance'), findsOneWidget);
    expect(find.text('Expected cash'), findsOneWidget);
    expect(find.text('Transactions'), findsWidgets);
    expect(find.text('Cash movement masuk'), findsWidgets);
    expect(find.text('Close cashier'), findsOneWidget);
    expect(find.textContaining('Omzet non-tunai'), findsWidgets);
    expect(find.textContaining('tidak dihitung'), findsOneWidget);

    await tester.tap(find.text('Close cashier'));
    await tester.pumpAndSettle();
    expect(find.text('Actual cash'), findsOneWidget);
    expect(find.text('Simpan closing report'), findsOneWidget);
  });

  testWidgets('tanpa sesi menampilkan Open cashier', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => SeededAuthController(user: owner),
          ),
          activeBusinessIdProvider.overrideWith((Ref ref) async => 'biz-1'),
          cashRepositoryProvider.overrideWithValue(_FakeCashRepository()),
        ],
        child: const MaterialApp(home: CashManagementPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open cashier'), findsWidgets);
    expect(find.text('Opening balance'), findsOneWidget);
  });
}

final class _FakeCashRepository implements CashRepository {
  _FakeCashRepository({this.open});

  CashSession? open;

  @override
  Future<CashSession> openSession({
    required String businessId,
    required int openingAmount,
    String? userId,
  }) async {
    open = CashSession(
      id: 'ses-new',
      businessId: businessId,
      userId: userId,
      openingAmount: openingAmount,
      status: CashSessionStatus.open,
      openedAt: 1,
      createdAt: 1,
      updatedAt: 1,
    );
    return open!;
  }

  @override
  Future<CashMovement> addMovement({
    required String sessionId,
    required String type,
    required int amount,
    String? note,
  }) async {
    return CashMovement(
      id: 'm1',
      businessId: 'biz-1',
      sessionId: sessionId,
      type: type,
      amount: amount,
      note: note,
      createdAt: 1,
    );
  }

  @override
  Future<CashSession> closeSession({
    required String sessionId,
    required int countedAmount,
  }) async {
    return CashSession(
      id: sessionId,
      businessId: 'biz-1',
      openingAmount: 100000,
      closingAmount: countedAmount,
      expectedAmount: 90000,
      differenceAmount: countedAmount - 90000,
      status: CashSessionStatus.closed,
      openedAt: 1,
      closedAt: 2,
      createdAt: 1,
      updatedAt: 2,
    );
  }

  @override
  Future<CashSession?> getOpenSession(String businessId) async => open;

  @override
  Future<CashSession?> getSession(String id) async => open;

  @override
  Future<CashDrawerSnapshot> drawer(String sessionId) async {
    final CashSession session = open!;
    return CashDrawerSnapshot(
      session: session,
      cashSales: 10000,
      nonCashSales: 5000,
      cashIn: 0,
      cashOut: 20000,
      expectedAmount: 90000,
      transactionCount: 2,
      movements: const <CashMovement>[],
      sales: const <SessionSaleRow>[
        SessionSaleRow(
          transactionId: 't1',
          createdAt: 1755514800000,
          totalAmount: 10000,
          cashAmount: 10000,
          nonCashAmount: 0,
        ),
      ],
    );
  }

  @override
  Future<List<CashSession>> listClosed({
    required String businessId,
    int limit = 20,
  }) async => const <CashSession>[];
}
