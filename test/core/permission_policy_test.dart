import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_policy.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';

void main() {
  final PermissionPolicy policy = PermissionPolicy.standard();

  test('owner memiliki seluruh izin', () {
    for (final AppPermission permission in AppPermission.values) {
      expect(policy.allows(UserRole.owner, permission), isTrue);
    }
  });

  test('admin sesuai modul operasional, tanpa kasir dan kelola user', () {
    expect(policy.allows(UserRole.admin, AppPermission.manageProducts), isTrue);
    expect(policy.allows(UserRole.admin, AppPermission.manageStock), isTrue);
    expect(
      policy.allows(UserRole.admin, AppPermission.viewTransactions),
      isTrue,
    );
    expect(policy.allows(UserRole.admin, AppPermission.viewReports), isTrue);
    expect(
      policy.allows(UserRole.admin, AppPermission.manageCustomers),
      isTrue,
    );
    expect(
      policy.allows(UserRole.admin, AppPermission.manageSuppliers),
      isTrue,
    );
    expect(policy.allows(UserRole.admin, AppPermission.manageExpenses), isTrue);
    expect(policy.allows(UserRole.admin, AppPermission.manageCash), isTrue);
    expect(policy.allows(UserRole.admin, AppPermission.cashier), isFalse);
    expect(
      policy.allows(UserRole.admin, AppPermission.managePrinters),
      isFalse,
    );
    expect(policy.allows(UserRole.admin, AppPermission.manageUsers), isFalse);
    expect(
      policy.allows(UserRole.admin, AppPermission.manageSubscription),
      isFalse,
    );
  });

  test('kasir terbatas pada kasir, transaksi, pelanggan, printer', () {
    expect(policy.allows(UserRole.cashier, AppPermission.cashier), isTrue);
    expect(
      policy.allows(UserRole.cashier, AppPermission.viewTransactions),
      isTrue,
    );
    expect(
      policy.allows(UserRole.cashier, AppPermission.manageCustomers),
      isTrue,
    );
    expect(
      policy.allows(UserRole.cashier, AppPermission.manageSuppliers),
      isFalse,
    );
    expect(
      policy.allows(UserRole.cashier, AppPermission.managePrinters),
      isTrue,
    );
    expect(
      policy.allows(UserRole.cashier, AppPermission.manageProducts),
      isFalse,
    );
    expect(policy.allows(UserRole.cashier, AppPermission.manageStock), isFalse);
    expect(policy.allows(UserRole.cashier, AppPermission.viewReports), isFalse);
    expect(
      policy.allows(UserRole.cashier, AppPermission.manageExpenses),
      isFalse,
    );
    expect(policy.allows(UserRole.cashier, AppPermission.manageCash), isTrue);
  });

  test('kebijakan dapat diperluas tanpa mengubah peta lama', () {
    final PermissionPolicy extended = policy.extend(UserRole.cashier, {
      AppPermission.viewReports,
    });
    expect(policy.allows(UserRole.cashier, AppPermission.viewReports), isFalse);
    expect(
      extended.allows(UserRole.cashier, AppPermission.viewReports),
      isTrue,
    );
    expect(extended.allows(UserRole.cashier, AppPermission.cashier), isTrue);
  });
}
