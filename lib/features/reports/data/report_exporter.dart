import 'package:excel/excel.dart';
import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:pdf/widgets.dart' as pw;

/// Ekspor laporan. Sel uang/qty hanya [int] — tidak ada double.
abstract final class ReportExporter {
  static const String utf8Bom = '\uFEFF';

  static String csv(ReportSnapshot snapshot, {required ReportQuery query}) {
    final StringBuffer out = StringBuffer(utf8Bom);
    for (final _ExportSection section in _sections(snapshot, query: query)) {
      out.writeln(_escape(section.title));
      out.writeln(section.headers.map(_escape).join(','));
      for (final List<Object> row in section.rows) {
        out.writeln(row.map(_csvCell).join(','));
      }
      out.writeln();
    }
    return out.toString();
  }

  static List<int> excel(
    ReportSnapshot snapshot, {
    required ReportQuery query,
  }) {
    final Excel book = Excel.createExcel();
    final String? defaultSheet = book.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != 'Laporan') {
      book.rename(defaultSheet, 'Laporan');
    }
    final Sheet sheet = book['Laporan'];
    for (final _ExportSection section in _sections(snapshot, query: query)) {
      sheet.appendRow(<CellValue?>[TextCellValue(section.title)]);
      sheet.appendRow(
        section.headers.map((String h) => TextCellValue(h)).toList(),
      );
      for (final List<Object> row in section.rows) {
        sheet.appendRow(row.map(_excelCell).toList());
      }
      sheet.appendRow(const <CellValue?>[]);
    }
    final List<int>? bytes = book.save();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Gagal membuat berkas Excel');
    }
    return bytes;
  }

  static Future<List<int>> pdf(
    ReportSnapshot snapshot, {
    required ReportQuery query,
  }) async {
    final pw.Document doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (pw.Context context) {
          return [
            pw.Text(
              'Laporan ${Brand.appName}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '${Brand.companyName} · ${Brand.websiteHost}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 12),
            for (final _ExportSection section in _sections(
              snapshot,
              query: query,
            )) ...[
              pw.Text(
                section.title,
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              if (section.rows.isEmpty)
                pw.Text(
                  'Tidak ada data',
                  style: const pw.TextStyle(fontSize: 8),
                )
              else
                pw.TableHelper.fromTextArray(
                  headers: section.headers,
                  data: [
                    for (final List<Object> row in section.rows)
                      row.map(_pdfCell).toList(),
                  ],
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 8,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              pw.SizedBox(height: 12),
            ],
          ];
        },
      ),
    );
    return doc.save();
  }

  static List<_ExportSection> _sections(
    ReportSnapshot snapshot, {
    required ReportQuery query,
  }) {
    final String from = DateFormatter.dateId(
      DateTime.fromMillisecondsSinceEpoch(query.range.startMs),
    );
    final String to = DateFormatter.dateId(
      DateTime.fromMillisecondsSinceEpoch(query.range.endMsExclusive - 1),
    );
    return <_ExportSection>[
      _ExportSection(
        title: 'Ringkasan',
        headers: const <String>['Metrik', 'Nilai'],
        rows: <List<Object>>[
          <Object>['Periode', '$from - $to'],
          <Object>['Penjualan (transaksi)', snapshot.transactionCount],
          <Object>['Omzet', snapshot.omzet],
          <Object>['HPP', snapshot.cogs],
          <Object>['Laba kotor', snapshot.grossProfit],
          <Object>['Produk terjual', snapshot.productsSoldQty],
          <Object>['Pengeluaran', snapshot.expensesTotal],
          <Object>['Saldo kas', snapshot.cash.currentBalance],
          <Object>['Penjualan tunai periode', snapshot.cash.periodCashSales],
          <Object>['Omzet non-tunai periode', snapshot.cash.periodNonCashSales],
          <Object>['Kas masuk periode', snapshot.cash.periodCashIn],
          <Object>['Kas keluar periode', snapshot.cash.periodCashOut],
          <Object>['Kas neto periode', snapshot.cash.periodNet],
        ],
      ),
      _ExportSection(
        title: 'Penjualan',
        headers: const <String>['Waktu', 'Kasir', 'Nominal'],
        rows: [
          for (final ReportSaleRow row in snapshot.sales)
            <Object>[
              DateFormatter.dateTimeId(
                DateTime.fromMillisecondsSinceEpoch(row.createdAt),
              ),
              row.cashierName,
              row.amount,
            ],
        ],
      ),
      _ExportSection(
        title: 'Produk terlaris',
        headers: const <String>['Produk', 'Qty', 'Omzet', 'HPP', 'Laba kotor'],
        rows: [
          for (final ReportNamedAmount row in snapshot.topProducts)
            <Object>[row.name, row.qty, row.amount, row.cogs, row.grossProfit],
        ],
      ),
      _ExportSection(
        title: 'Stok',
        headers: const <String>['Produk', 'Kategori', 'Qty', 'Minimum'],
        rows: [
          for (final ReportStockRow row in snapshot.stock)
            <Object>[row.name, row.categoryName ?? '', row.qty, row.minStock],
        ],
      ),
      _ExportSection(
        title: 'Stok menipis',
        headers: const <String>['Produk', 'Qty', 'Minimum'],
        rows: [
          for (final ReportStockRow row in snapshot.lowStock)
            <Object>[row.name, row.qty, row.minStock],
        ],
      ),
      _ExportSection(
        title: 'Pengeluaran',
        headers: const <String>['Waktu', 'Kategori', 'Catatan', 'Nominal'],
        rows: [
          for (final ReportExpenseRow row in snapshot.expenses)
            <Object>[
              DateFormatter.dateTimeId(
                DateTime.fromMillisecondsSinceEpoch(row.spentAt),
              ),
              row.categoryName ?? '',
              row.note ?? '',
              row.amount,
            ],
        ],
      ),
      _ExportSection(
        title: 'Metode pembayaran',
        headers: const <String>['Metode', 'Transaksi', 'Nominal'],
        rows: [
          for (final ReportNamedAmount row in snapshot.paymentMethods)
            <Object>[row.name, row.count, row.amount],
        ],
      ),
      _ExportSection(
        title: 'Penjualan per kasir',
        headers: const <String>['Kasir', 'Transaksi', 'Omzet'],
        rows: [
          for (final ReportNamedAmount row in snapshot.salesByCashier)
            <Object>[row.name, row.count, row.amount],
        ],
      ),
      _ExportSection(
        title: 'Penjualan per kategori',
        headers: const <String>['Kategori', 'Qty', 'Omzet'],
        rows: [
          for (final ReportNamedAmount row in snapshot.salesByCategory)
            <Object>[row.name, row.qty, row.amount],
        ],
      ),
    ];
  }

  static String _csvCell(Object value) => _escape(_plain(value));

  static CellValue _excelCell(Object value) {
    if (value is int) {
      return IntCellValue(value);
    }
    if (value is String) {
      return TextCellValue(value);
    }
    throw StateError(
      'Sel Excel harus String atau int, bukan ${value.runtimeType}',
    );
  }

  static String _pdfCell(Object value) => _plain(value);

  static String _plain(Object value) {
    if (value is int) {
      return value.toString();
    }
    if (value is String) {
      return value;
    }
    throw StateError(
      'Sel ekspor harus String atau int, bukan ${value.runtimeType}',
    );
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

final class _ExportSection {
  const _ExportSection({
    required this.title,
    required this.headers,
    required this.rows,
  });

  final String title;
  final List<String> headers;
  final List<List<Object>> rows;
}
