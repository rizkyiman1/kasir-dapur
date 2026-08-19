import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_repository.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';

final class GuardedDashboardRepository implements DashboardRepository {
  GuardedDashboardRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final DashboardRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  @override
  Future<DashboardSnapshot> load({required DashboardDateRange range}) {
    _guard.require(_access(), AppPermission.viewDashboard);
    return _inner.load(range: range);
  }
}
