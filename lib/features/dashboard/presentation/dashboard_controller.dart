import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';

final class DashboardFilterController extends Notifier<DashboardFilter> {
  @override
  DashboardFilter build() => const DashboardFilter();

  void setPeriod(DashboardPeriod period) {
    if (period == DashboardPeriod.custom) {
      state = state.copyWith(period: period);
      return;
    }
    state = state.copyWith(period: period, clearCustom: true);
  }

  void setCustomRange({required DateTime start, required DateTime end}) {
    state = DashboardFilter(
      period: DashboardPeriod.custom,
      customStart: DashboardDateRange.startOfLocalDay(start),
      customEnd: DashboardDateRange.startOfLocalDay(end),
    );
  }
}

final dashboardFilterProvider =
    NotifierProvider<DashboardFilterController, DashboardFilter>(
      DashboardFilterController.new,
    );

final dashboardSnapshotProvider = FutureProvider<DashboardSnapshot>((Ref ref) {
  final DashboardFilter filter = ref.watch(dashboardFilterProvider);
  final range = filter.rangeFor(ref.watch(clockProvider).now());
  return ref.watch(dashboardRepositoryProvider).load(range: range);
});
