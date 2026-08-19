import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:kasir_dapur/features/dashboard/presentation/dashboard_page.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/services/clock_service.dart';

import '../../helpers/fakes.dart';

const AuthUser _owner = AuthUser(
  id: 'o1',
  displayName: 'Budi',
  role: UserRole.owner,
);
const AuthUser _cashier = AuthUser(
  id: 'c1',
  displayName: 'Cici',
  role: UserRole.cashier,
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Widget app({
    required AuthUser user,
    required FakeDashboardRepository dashboard,
  }) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => SeededAuthController(user: user),
        ),
        dashboardRepositoryProvider.overrideWithValue(dashboard),
        featureGateProvider.overrideWith(
          (Ref ref) async => FeatureGate.forPlan(Plan.business),
        ),
        clockProvider.overrideWithValue(
          AdjustableClock(DateTime(2026, 8, 18, 15)),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('id', 'ID'),
        supportedLocales: [Locale('id', 'ID')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DashboardPage(),
      ),
    );
  }

  Future<void> tallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('loading, empty, dan data owner', (tester) async {
    await tallSurface(tester);
    final FakeDashboardRepository dashboard = FakeDashboardRepository();
    await tester.pumpWidget(app(user: _owner, dashboard: dashboard));
    expect(find.text('Memuat ringkasan usaha...'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Halo, Budi'), findsOneWidget);
    expect(find.text('Belum ada aktivitas'), findsOneWidget);
    expect(find.text('Omzet'), findsOneWidget);

    dashboard.snapshot = const DashboardSnapshot(
      businessId: 'b1',
      omzet: 25000,
      transactionCount: 1,
      grossProfit: 9000,
      productsSoldQty: 2,
      expensesTotal: 15000,
      cashBalance: 130000,
      hasOpenCashSession: true,
      lowStock: [
        LowStockItem(productId: 'p1', name: 'Es Teh', qty: 2, minStock: 5),
      ],
      recentSales: [
        DashboardSaleSummary(id: 's1', totalAmount: 25000, createdAt: 1),
      ],
    );
    await tester.tap(find.text('Kemarin'));
    await tester.pumpAndSettle();

    expect(find.text('Rp25.000'), findsWidgets);
    expect(find.text('Pengeluaran'), findsWidgets);
    expect(find.text('Saldo kas'), findsOneWidget);
    expect(find.text('Stok menipis'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);
    expect(find.text('Transaksi terbaru'), findsOneWidget);
    expect(find.text('Belum ada aktivitas'), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -2400));
    await tester.pumpAndSettle();
    expect(find.textContaining(Brand.companyName), findsWidgets);
    expect(find.textContaining(Brand.websiteHost), findsWidgets);
  });

  testWidgets('kasir tidak melihat pengeluaran dan stok', (tester) async {
    await tallSurface(tester);
    final FakeDashboardRepository dashboard = FakeDashboardRepository(
      snapshot: const DashboardSnapshot(
        businessId: 'b1',
        omzet: 25000,
        transactionCount: 1,
        grossProfit: 9000,
        productsSoldQty: 2,
        expensesTotal: 15000,
        cashBalance: 130000,
        hasOpenCashSession: true,
        lowStock: [
          LowStockItem(productId: 'p1', name: 'Es Teh', qty: 2, minStock: 5),
        ],
        recentSales: [
          DashboardSaleSummary(id: 's1', totalAmount: 25000, createdAt: 1),
        ],
      ),
    );

    await tester.pumpWidget(app(user: _cashier, dashboard: dashboard));
    await tester.pumpAndSettle();

    expect(find.text('Omzet'), findsOneWidget);
    expect(find.text('Laba kotor'), findsOneWidget);
    expect(find.text('Transaksi terbaru'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsNothing);
    expect(find.text('Saldo kas'), findsOneWidget);
    expect(find.text('Stok menipis'), findsNothing);
    expect(find.text('Es Teh'), findsNothing);
  });

  testWidgets('error state dapat dicoba lagi', (tester) async {
    final FakeDashboardRepository dashboard = FakeDashboardRepository(
      error: const DatabaseException('Database lokal gagal dibaca.'),
    );
    await tester.pumpWidget(app(user: _owner, dashboard: dashboard));
    await tester.pumpAndSettle();

    expect(find.text('Dashboard gagal dimuat'), findsOneWidget);
    expect(find.text('Database lokal gagal dibaca.'), findsOneWidget);

    dashboard.error = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Budi'), findsOneWidget);
  });
}
