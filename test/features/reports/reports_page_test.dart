import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';
import 'package:kasir_dapur/features/reports/presentation/reports_page.dart';
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

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  Widget app({required FakeReportRepository reports}) {
    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => SeededAuthController(user: _owner),
        ),
        reportRepositoryProvider.overrideWithValue(reports),
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
        home: ReportsPage(),
      ),
    );
  }

  Future<void> tallSurface(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('menampilkan angka laporan dari repository', (tester) async {
    await tallSurface(tester);
    final FakeReportRepository reports = FakeReportRepository(
      snapshot: const ReportSnapshot(
        businessId: 'b1',
        omzet: 25000,
        transactionCount: 1,
        productsSoldQty: 2,
        cogs: 16000,
        grossProfit: 9000,
        expensesTotal: 15000,
        sales: [
          ReportSaleRow(
            id: 's1',
            createdAt: 1755514800000,
            amount: 25000,
            cashierName: 'Siti',
          ),
        ],
        topProducts: [
          ReportNamedAmount(
            id: 'p1',
            name: 'Nasi Goreng',
            amount: 25000,
            qty: 2,
          ),
        ],
        stock: [
          ReportStockRow(
            productId: 'p1',
            name: 'Nasi Goreng',
            qty: 8,
            minStock: 2,
          ),
        ],
        lowStock: [
          ReportStockRow(productId: 'p2', name: 'Es Teh', qty: 2, minStock: 5),
        ],
        expenses: [
          ReportExpenseRow(
            id: 'e1',
            amount: 15000,
            spentAt: 1755514800000,
            note: 'Sayur',
          ),
        ],
        cash: ReportCashSnapshot(
          currentBalance: 130000,
          hasOpenSession: true,
          periodCashSales: 25000,
          periodCashIn: 10000,
          periodCashOut: 5000,
        ),
        paymentMethods: [
          ReportNamedAmount(id: 'cash', name: 'Tunai', amount: 25000, count: 1),
        ],
        salesByCashier: [
          ReportNamedAmount(id: 'u1', name: 'Siti', amount: 25000, count: 1),
        ],
        salesByCategory: [
          ReportNamedAmount(id: 'c1', name: 'Makanan', amount: 25000, qty: 2),
        ],
      ),
    );

    await tester.pumpWidget(app(reports: reports));
    await tester.pumpAndSettle();

    expect(find.text('Laporan'), findsOneWidget);
    expect(find.text('Omzet'), findsWidgets);
    expect(find.text('Rp25.000'), findsWidgets);
    expect(find.text('Laba kotor'), findsOneWidget);
    expect(find.text('Rp9.000'), findsWidgets);
    expect(find.text('Produk terlaris'), findsOneWidget);
    expect(find.text('Nasi Goreng'), findsWidgets);
    expect(find.text('Stok menipis'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Penjualan per kategori'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Metode pembayaran'), findsOneWidget);
    expect(find.text('Penjualan per kasir'), findsOneWidget);
    expect(find.text('Penjualan per kategori'), findsOneWidget);
    expect(find.text('Tunai'), findsWidgets);
    expect(find.text('Makanan'), findsOneWidget);
  });

  testWidgets('error state dapat dicoba lagi', (tester) async {
    await tallSurface(tester);
    final FakeReportRepository reports = FakeReportRepository(
      error: const DatabaseException('Database lokal gagal dibaca.'),
    );
    await tester.pumpWidget(app(reports: reports));
    await tester.pumpAndSettle();

    expect(find.text('Laporan gagal dimuat'), findsOneWidget);
    expect(find.text('Database lokal gagal dibaca.'), findsOneWidget);

    reports.error = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('Belum ada penjualan pada periode ini.'), findsOneWidget);
  });
}
