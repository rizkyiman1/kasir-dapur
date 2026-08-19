import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';

abstract class DashboardRepository {
  Future<DashboardSnapshot> load({required DashboardDateRange range});
}
