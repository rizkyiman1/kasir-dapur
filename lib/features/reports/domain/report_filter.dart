import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';

/// Filter laporan. Tanggal inklusif di [DashboardDateRange.startMs],
/// eksklusif di [endMsExclusive].
final class ReportFilter {
  const ReportFilter({
    this.period = DashboardPeriod.today,
    this.customStart,
    this.customEnd,
    this.productId,
    this.categoryId,
    this.cashierId,
    this.paymentMethod,
  });

  /// Nilai [cashierId] untuk transaksi tanpa kasir.
  static const String noCashierId = '__none__';

  final DashboardPeriod period;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? productId;
  final String? categoryId;
  final String? cashierId;
  final String? paymentMethod;

  bool get hasLineFilter => productId != null || categoryId != null;

  DashboardDateRange rangeFor(DateTime now) {
    return DashboardDateRange.resolve(
      period: period,
      now: now,
      customStart: customStart,
      customEnd: customEnd,
    );
  }

  ReportQuery toQuery(DateTime now) {
    return ReportQuery(
      range: rangeFor(now),
      productId: productId,
      categoryId: categoryId,
      cashierId: cashierId,
      paymentMethod: paymentMethod,
    );
  }

  ReportFilter copyWith({
    DashboardPeriod? period,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearCustom = false,
    String? productId,
    bool clearProduct = false,
    String? categoryId,
    bool clearCategory = false,
    String? cashierId,
    bool clearCashier = false,
    String? paymentMethod,
    bool clearPayment = false,
  }) {
    return ReportFilter(
      period: period ?? this.period,
      customStart: clearCustom ? null : (customStart ?? this.customStart),
      customEnd: clearCustom ? null : (customEnd ?? this.customEnd),
      productId: clearProduct ? null : (productId ?? this.productId),
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      cashierId: clearCashier ? null : (cashierId ?? this.cashierId),
      paymentMethod: clearPayment
          ? null
          : (paymentMethod ?? this.paymentMethod),
    );
  }
}

/// Query siap kirim ke SQLite. Semua ID opsional.
final class ReportQuery {
  const ReportQuery({
    required this.range,
    this.productId,
    this.categoryId,
    this.cashierId,
    this.paymentMethod,
  });

  final DashboardDateRange range;
  final String? productId;
  final String? categoryId;
  final String? cashierId;
  final String? paymentMethod;

  bool get hasLineFilter => productId != null || categoryId != null;
}

final class ReportFilterOption {
  const ReportFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

final class ReportFilterOptions {
  const ReportFilterOptions({
    this.products = const [],
    this.categories = const [],
    this.cashiers = const [],
  });

  final List<ReportFilterOption> products;
  final List<ReportFilterOption> categories;
  final List<ReportFilterOption> cashiers;
}
