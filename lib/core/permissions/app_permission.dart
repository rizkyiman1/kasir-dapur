/// Izin aplikasi. Dapat ditambah tanpa mengubah role yang sudah ada.
enum AppPermission {
  viewDashboard,
  cashier,
  viewProducts,
  manageProducts,
  manageStock,
  viewTransactions,
  viewReports,
  manageCustomers,
  manageSuppliers,
  manageExpenses,
  manageCash,
  managePrinters,
  manageBarcode,
  manageSubscription,
  manageSync,
  manageUsers,
  manageSettings,
  lockSession,
}

extension AppPermissionLabel on AppPermission {
  String get label {
    return switch (this) {
      AppPermission.viewDashboard => 'Lihat dashboard',
      AppPermission.cashier => 'Kasir',
      AppPermission.viewProducts => 'Lihat produk',
      AppPermission.manageProducts => 'Kelola produk',
      AppPermission.manageStock => 'Kelola stok',
      AppPermission.viewTransactions => 'Lihat transaksi',
      AppPermission.viewReports => 'Lihat laporan',
      AppPermission.manageCustomers => 'Kelola pelanggan',
      AppPermission.manageSuppliers => 'Kelola pemasok',
      AppPermission.manageExpenses => 'Kelola pengeluaran',
      AppPermission.manageCash => 'Kelola kas',
      AppPermission.managePrinters => 'Kelola printer',
      AppPermission.manageBarcode => 'Kelola barcode',
      AppPermission.manageSubscription => 'Kelola langganan',
      AppPermission.manageSync => 'Kelola sinkronisasi',
      AppPermission.manageUsers => 'Kelola pengguna',
      AppPermission.manageSettings => 'Kelola pengaturan',
      AppPermission.lockSession => 'Kunci layar',
    };
  }
}
