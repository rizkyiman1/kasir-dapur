import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';

final class ReportFilterController extends Notifier<ReportFilter> {
  @override
  ReportFilter build() => const ReportFilter();

  void setPeriod(DashboardPeriod period) {
    if (period == DashboardPeriod.custom) {
      state = state.copyWith(period: period);
      return;
    }
    state = state.copyWith(period: period, clearCustom: true);
  }

  void setCustomRange({required DateTime start, required DateTime end}) {
    state = ReportFilter(
      period: DashboardPeriod.custom,
      customStart: DashboardDateRange.startOfLocalDay(start),
      customEnd: DashboardDateRange.startOfLocalDay(end),
      productId: state.productId,
      categoryId: state.categoryId,
      cashierId: state.cashierId,
      paymentMethod: state.paymentMethod,
    );
  }

  void setProductId(String? id) {
    state = state.copyWith(productId: id, clearProduct: id == null);
  }

  void setCategoryId(String? id) {
    state = state.copyWith(categoryId: id, clearCategory: id == null);
  }

  void setCashierId(String? id) {
    state = state.copyWith(cashierId: id, clearCashier: id == null);
  }

  void setPaymentMethod(String? method) {
    state = state.copyWith(paymentMethod: method, clearPayment: method == null);
  }
}

final reportFilterProvider =
    NotifierProvider<ReportFilterController, ReportFilter>(
      ReportFilterController.new,
    );

final reportSnapshotProvider = FutureProvider<ReportSnapshot>((Ref ref) {
  final ReportFilter filter = ref.watch(reportFilterProvider);
  final ReportQuery query = filter.toQuery(ref.watch(clockProvider).now());
  return ref.watch(reportRepositoryProvider).load(query);
});

final reportFilterOptionsProvider = FutureProvider<ReportFilterOptions>((
  Ref ref,
) {
  return ref.watch(reportRepositoryProvider).filterOptions();
});
