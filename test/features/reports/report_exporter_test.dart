import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/reports/data/report_exporter.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  final ReportQuery query = ReportQuery(
    range: DashboardDateRange.resolve(
      period: DashboardPeriod.today,
      now: DateTime(2026, 8, 18, 15),
    ),
  );

  const ReportSnapshot snapshot = ReportSnapshot(
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
        cogs: 16000,
        grossProfit: 9000,
      ),
    ],
    stock: [
      ReportStockRow(
        productId: 'p1',
        name: 'Nasi Goreng',
        qty: 8,
        minStock: 2,
        categoryName: 'Makanan',
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
        categoryName: 'Dapur',
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
  );

  test('CSV memakai integer polos, bukan pecahan', () {
    final String csv = ReportExporter.csv(snapshot, query: query);
    expect(csv.startsWith(ReportExporter.utf8Bom), isTrue);
    expect(csv, contains('Omzet,25000'));
    expect(csv, contains('Laba kotor,9000'));
    expect(csv, contains('Pengeluaran,15000'));
    expect(csv, contains('Nasi Goreng,2,25000,16000,9000'));
    expect(csv, contains('Tunai,1,25000'));
    expect(csv, isNot(contains('25000.0')));
    expect(csv, isNot(contains('9000.0')));
    expect(utf8.encode(csv).take(3).toList(), <int>[0xEF, 0xBB, 0xBF]);
  });

  test('Excel menyimpan omzet sebagai IntCellValue', () {
    final List<int> bytes = ReportExporter.excel(snapshot, query: query);
    expect(bytes.take(2).toList(), <int>[0x50, 0x4B]);
    final Excel book = Excel.decodeBytes(bytes);
    final Sheet sheet = book['Laporan'];
    var foundOmzet = false;
    for (final List<Data?> row in sheet.rows) {
      if (row.length < 2) {
        continue;
      }
      final CellValue? label = row[0]?.value;
      final CellValue? value = row[1]?.value;
      if (label is TextCellValue && label.value.text == 'Omzet') {
        expect(value, isA<IntCellValue>());
        expect((value! as IntCellValue).value, 25000);
        foundOmzet = true;
      }
      expect(value, isNot(isA<DoubleCellValue>()));
    }
    expect(foundOmzet, isTrue);
  });

  test('PDF terbuat dan memuat angka integer laporan', () async {
    final List<int> bytes = await ReportExporter.pdf(snapshot, query: query);
    expect(bytes.length, greaterThan(100));
    expect(ascii.decode(bytes.take(4).toList()), '%PDF');
  });
}
