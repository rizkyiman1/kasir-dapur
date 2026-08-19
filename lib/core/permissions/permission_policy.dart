import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';

/// Peta role → izin. Bisa diperluas lewat [extend].
final class PermissionPolicy {
  const PermissionPolicy(this._grants);

  final Map<UserRole, Set<AppPermission>> _grants;

  static PermissionPolicy standard() {
    const Set<AppPermission> cashier = {
      AppPermission.viewDashboard,
      AppPermission.cashier,
      AppPermission.viewProducts,
      AppPermission.viewTransactions,
      AppPermission.manageCustomers,
      AppPermission.manageCash,
      AppPermission.managePrinters,
      AppPermission.manageBarcode,
      AppPermission.lockSession,
    };
    const Set<AppPermission> admin = {
      AppPermission.viewDashboard,
      AppPermission.viewProducts,
      AppPermission.manageProducts,
      AppPermission.manageStock,
      AppPermission.viewTransactions,
      AppPermission.viewReports,
      AppPermission.manageCustomers,
      AppPermission.manageSuppliers,
      AppPermission.manageExpenses,
      AppPermission.manageCash,
      AppPermission.lockSession,
    };
    return PermissionPolicy({
      UserRole.owner: AppPermission.values.toSet(),
      UserRole.admin: admin,
      UserRole.cashier: cashier,
    });
  }

  bool allows(UserRole role, AppPermission permission) {
    return _grants[role]?.contains(permission) ?? false;
  }

  Set<AppPermission> permissionsFor(UserRole role) {
    return Set<AppPermission>.unmodifiable(_grants[role] ?? <AppPermission>{});
  }

  PermissionPolicy extend(UserRole role, Set<AppPermission> extra) {
    final Map<UserRole, Set<AppPermission>> next =
        Map<UserRole, Set<AppPermission>>.from(_grants);
    next[role] = <AppPermission>{...?next[role], ...extra};
    return PermissionPolicy(next);
  }
}
