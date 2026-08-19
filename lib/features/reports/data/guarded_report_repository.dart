import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_repository.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';

final class GuardedReportRepository implements ReportRepository {
  GuardedReportRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final ReportRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _read() => _guard.require(_access(), AppPermission.viewReports);

  @override
  Future<ReportSnapshot> load(ReportQuery query) {
    _read();
    return _inner.load(query);
  }

  @override
  Future<ReportFilterOptions> filterOptions() {
    _read();
    return _inner.filterOptions();
  }
}
