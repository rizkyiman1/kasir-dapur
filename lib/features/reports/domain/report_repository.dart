import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';

abstract class ReportRepository {
  Future<ReportSnapshot> load(ReportQuery query);
  Future<ReportFilterOptions> filterOptions();
}

enum ReportExportFormat {
  csv,
  excel,
  pdf;

  String get extension {
    return switch (this) {
      ReportExportFormat.csv => 'csv',
      ReportExportFormat.excel => 'xlsx',
      ReportExportFormat.pdf => 'pdf',
    };
  }

  String get label {
    return switch (this) {
      ReportExportFormat.csv => 'CSV',
      ReportExportFormat.excel => 'Excel',
      ReportExportFormat.pdf => 'PDF',
    };
  }

  String get mimeType {
    return switch (this) {
      ReportExportFormat.csv => 'text/csv',
      ReportExportFormat.excel =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ReportExportFormat.pdf => 'application/pdf',
    };
  }
}
