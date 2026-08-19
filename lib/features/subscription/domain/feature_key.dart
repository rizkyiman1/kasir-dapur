import 'package:kasir_dapur/core/errors/app_exception.dart';

/// Kunci fitur. Layar dan layanan memakai ini, bukan nama paket.
enum FeatureKey {
  maxBusinesses,
  maxProducts,
  maxOwners,
  maxCashiers,
  maxDevices,
  maxBranches,
  offlinePos,
  basicInventory,
  dailyReports,
  barcode,
  basicReceipt,
  multipleCashiers,
  advancedReports,
  export,
  customers,
  suppliers,
  expenses,
  profitAnalysis,
  cloudBackup,
  googleSheetsSync,
  advancedPrinter,
  dashboard,
  discountVoucher,
  multiBranch,
  multiDevice,
  multiUser,
  advancedPermission,
  centralDashboard,
  cloudSync,
  advancedReport,
  apiAccess,
  advancedBackup,
  prioritySupport,
  businessFeatures;

  String get storageValue {
    return switch (this) {
      FeatureKey.maxBusinesses => 'max_businesses',
      FeatureKey.maxProducts => 'max_products',
      FeatureKey.maxOwners => 'max_owners',
      FeatureKey.maxCashiers => 'max_cashiers',
      FeatureKey.maxDevices => 'max_devices',
      FeatureKey.maxBranches => 'max_branches',
      FeatureKey.offlinePos => 'offline_pos',
      FeatureKey.basicInventory => 'basic_inventory',
      FeatureKey.dailyReports => 'daily_reports',
      FeatureKey.barcode => 'barcode',
      FeatureKey.basicReceipt => 'basic_receipt',
      FeatureKey.multipleCashiers => 'multiple_cashiers',
      FeatureKey.advancedReports => 'advanced_reports',
      FeatureKey.export => 'export',
      FeatureKey.customers => 'customers',
      FeatureKey.suppliers => 'suppliers',
      FeatureKey.expenses => 'expenses',
      FeatureKey.profitAnalysis => 'profit_analysis',
      FeatureKey.cloudBackup => 'cloud_backup',
      FeatureKey.googleSheetsSync => 'google_sheets',
      FeatureKey.advancedPrinter => 'advanced_printer',
      FeatureKey.dashboard => 'dashboard',
      FeatureKey.discountVoucher => 'discount_voucher',
      FeatureKey.multiBranch => 'multi_branch',
      FeatureKey.multiDevice => 'multi_device',
      FeatureKey.multiUser => 'multi_user',
      FeatureKey.advancedPermission => 'advanced_permission',
      FeatureKey.centralDashboard => 'central_dashboard',
      FeatureKey.cloudSync => 'cloud_sync',
      FeatureKey.advancedReport => 'advanced_report',
      FeatureKey.apiAccess => 'api',
      FeatureKey.advancedBackup => 'advanced_backup',
      FeatureKey.prioritySupport => 'priority_support',
      FeatureKey.businessFeatures => 'business_features',
    };
  }

  String get label {
    return switch (this) {
      FeatureKey.maxBusinesses => 'Jumlah usaha',
      FeatureKey.maxProducts => 'Jumlah produk',
      FeatureKey.maxOwners => 'Jumlah owner',
      FeatureKey.maxCashiers => 'Jumlah kasir',
      FeatureKey.maxDevices => 'Jumlah perangkat',
      FeatureKey.maxBranches => 'Jumlah cabang',
      FeatureKey.offlinePos => 'Kasir offline',
      FeatureKey.basicInventory => 'Inventori dasar',
      FeatureKey.dailyReports => 'Laporan harian',
      FeatureKey.barcode => 'Barcode',
      FeatureKey.basicReceipt => 'Struk dasar',
      FeatureKey.multipleCashiers => 'Beberapa kasir',
      FeatureKey.advancedReports => 'Laporan lanjutan',
      FeatureKey.export => 'Ekspor laporan',
      FeatureKey.customers => 'Pelanggan',
      FeatureKey.suppliers => 'Pemasok',
      FeatureKey.expenses => 'Pengeluaran',
      FeatureKey.profitAnalysis => 'Analisis laba',
      FeatureKey.cloudBackup => 'Cadangan cloud',
      FeatureKey.googleSheetsSync => 'Google Sheets',
      FeatureKey.advancedPrinter => 'Printer lanjutan',
      FeatureKey.dashboard => 'Dasbor lanjutan',
      FeatureKey.discountVoucher => 'Diskon & voucher',
      FeatureKey.multiBranch => 'Multi cabang',
      FeatureKey.multiDevice => 'Multi perangkat',
      FeatureKey.multiUser => 'Multi pengguna',
      FeatureKey.advancedPermission => 'Izin lanjutan',
      FeatureKey.centralDashboard => 'Dasbor pusat',
      FeatureKey.cloudSync => 'Sinkronisasi cloud',
      FeatureKey.advancedReport => 'Laporan bisnis',
      FeatureKey.apiAccess => 'API',
      FeatureKey.advancedBackup => 'Cadangan lanjutan',
      FeatureKey.prioritySupport => 'Dukungan prioritas',
      FeatureKey.businessFeatures => 'Fitur bisnis',
    };
  }

  bool get isLimit {
    return switch (this) {
      FeatureKey.maxBusinesses ||
      FeatureKey.maxProducts ||
      FeatureKey.maxOwners ||
      FeatureKey.maxCashiers ||
      FeatureKey.maxDevices ||
      FeatureKey.maxBranches => true,
      _ => false,
    };
  }

  static FeatureKey parse(String value) {
    for (final FeatureKey key in FeatureKey.values) {
      if (key.storageValue == value || key.name == value) {
        return key;
      }
    }
    throw ValidationException('Kunci fitur tidak dikenal: $value');
  }
}
