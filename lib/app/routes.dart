import 'package:kasir_dapur/core/permissions/app_permission.dart';

abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String lock = '/lock';
  static const String dashboard = '/dashboard';
  static const String cashier = '/cashier';
  static const String products = '/products';
  static const String categories = '/categories';
  static const String inventory = '/inventory';
  static const String stockCard = '/inventory/card';
  static const String stockOpname = '/inventory/opname';
  static const String stockHistory = '/inventory/history';
  static const String transactions = '/transactions';
  static const String reports = '/reports';
  static const String customers = '/customers';
  static const String suppliers = '/suppliers';
  static const String expenses = '/expenses';
  static const String cashManagement = '/cash-management';
  static const String printers = '/printers';
  static const String barcode = '/barcode';
  static const String subscription = '/subscription';
  static const String sync = '/sync';
  static const String backup = '/backup';
  static const String settings = '/settings';
  static const String users = '/users';

  /// Izin untuk rute. Null = cukup sudah masuk (bukan terkunci).
  static AppPermission? requiredPermission(String location) {
    return switch (location) {
      dashboard => AppPermission.viewDashboard,
      cashier => AppPermission.cashier,
      products => AppPermission.manageProducts,
      categories => AppPermission.manageProducts,
      inventory => AppPermission.manageStock,
      stockCard => AppPermission.manageStock,
      stockOpname => AppPermission.manageStock,
      stockHistory => AppPermission.manageStock,
      transactions => AppPermission.viewTransactions,
      reports => AppPermission.viewReports,
      customers => AppPermission.manageCustomers,
      suppliers => AppPermission.manageSuppliers,
      expenses => AppPermission.manageExpenses,
      cashManagement => AppPermission.manageCash,
      printers => AppPermission.managePrinters,
      barcode => AppPermission.manageBarcode,
      subscription => AppPermission.manageSubscription,
      sync => AppPermission.manageSync,
      backup => AppPermission.manageSettings,
      users => AppPermission.manageUsers,
      settings => null,
      _ => null,
    };
  }
}
