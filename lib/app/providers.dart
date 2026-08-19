import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/config/app_config.dart';
import 'package:kasir_dapur/config/env.dart';
import 'package:kasir_dapur/core/permissions/guarded_repositories.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/core/security/pin_hasher.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/auth/data/auth_repository_impl.dart';
import 'package:kasir_dapur/features/auth/data/cloud_auth_session_service.dart';
import 'package:kasir_dapur/features/auth/data/session_repository_impl.dart';
import 'package:kasir_dapur/features/auth/domain/auth_repository.dart';
import 'package:kasir_dapur/features/auth/domain/session.dart';
import 'package:kasir_dapur/features/auth/domain/session_repository.dart';
import 'package:kasir_dapur/features/backup/data/backup_gateway.dart';
import 'package:kasir_dapur/features/backup/data/backup_log_repository.dart';
import 'package:kasir_dapur/features/backup/data/backup_restorer.dart';
import 'package:kasir_dapur/features/backup/data/backup_snapshot_builder.dart';
import 'package:kasir_dapur/features/backup/domain/backup_gateway.dart';
import 'package:kasir_dapur/features/backup/domain/backup_service.dart';
import 'package:kasir_dapur/features/barcode/data/camera_permission_port.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_lookup_service.dart';
import 'package:kasir_dapur/features/barcode/domain/camera_permission.dart';
import 'package:kasir_dapur/features/cash_management/data/cash_repository_impl.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash_repository.dart';
import 'package:kasir_dapur/features/cashier/data/pos_cart_repository_impl.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart_repository.dart';
import 'package:kasir_dapur/features/customers/data/customer_repository_impl.dart';
import 'package:kasir_dapur/features/customers/domain/customer_repository.dart';
import 'package:kasir_dapur/features/dashboard/data/dashboard_repository_impl.dart';
import 'package:kasir_dapur/features/dashboard/data/guarded_dashboard_repository.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_repository.dart';
import 'package:kasir_dapur/features/expenses/data/expense_repository_impl.dart';
import 'package:kasir_dapur/features/expenses/domain/expense_repository.dart';
import 'package:kasir_dapur/features/inventory/data/stock_repository_impl.dart';
import 'package:kasir_dapur/features/inventory/domain/stock_repository.dart';
import 'package:kasir_dapur/features/printers/data/print_bluetooth_thermal_port.dart';
import 'package:kasir_dapur/features/printers/data/printer_repository_impl.dart';
import 'package:kasir_dapur/features/printers/domain/bluetooth_printer_port.dart';
import 'package:kasir_dapur/features/printers/domain/printer_repository.dart';
import 'package:kasir_dapur/features/printers/domain/printer_service.dart';
import 'package:kasir_dapur/features/products/data/business_repository_impl.dart';
import 'package:kasir_dapur/features/products/data/category_repository_impl.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/catalog_lookups.dart';
import 'package:kasir_dapur/features/products/domain/product_repository.dart';
import 'package:kasir_dapur/features/reports/data/guarded_report_repository.dart';
import 'package:kasir_dapur/features/reports/data/report_repository_impl.dart';
import 'package:kasir_dapur/features/reports/domain/report_repository.dart';
import 'package:kasir_dapur/features/settings/data/image_picker_logo_picker.dart';
import 'package:kasir_dapur/features/settings/data/store_repository_impl.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/domain/store_repository.dart';
import 'package:kasir_dapur/features/subscription/data/http_billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/data/subscription_repository_impl.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_gateway.dart';
import 'package:kasir_dapur/features/subscription/domain/entitlement_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_history_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';
import 'package:kasir_dapur/features/suppliers/data/supplier_repository_impl.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier_repository.dart';
import 'package:kasir_dapur/features/sync/data/cloud_sync_gateway.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/data/sync_snapshot_loader.dart';
import 'package:kasir_dapur/features/sync/domain/cloud_sync_gateway.dart';
import 'package:kasir_dapur/features/sync/domain/sync_engine.dart';
import 'package:kasir_dapur/features/sync/domain/sync_repository.dart';
import 'package:kasir_dapur/features/transactions/data/transaction_repository_impl.dart';
import 'package:kasir_dapur/features/transactions/domain/transaction_repository.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:kasir_dapur/services/settings_repository.dart';
import 'package:path_provider/path_provider.dart';

final envConfigProvider = Provider<EnvConfig>((Ref ref) {
  return EnvConfig.fromDartDefine();
});

final appConfigProvider = Provider<AppConfig>((Ref ref) {
  return AppConfig(env: ref.watch(envConfigProvider));
});

final clockProvider = Provider<ClockService>((Ref ref) {
  return const ClockService();
});

final pinHasherProvider = Provider<PinHasher>((Ref ref) {
  return PinHasher();
});

final appDatabaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});

final accessHolderProvider = Provider<AccessHolder>((Ref ref) {
  return AccessHolder();
});

final permissionGuardProvider = Provider<PermissionGuard>((Ref ref) {
  return PermissionGuard();
});

final sessionConfigProvider = Provider<SessionConfig>((Ref ref) {
  return const SessionConfig();
});

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return SqliteAuthRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
    pinHasher: ref.watch(pinHasherProvider),
  );
});

final sessionRepositoryProvider = Provider<SessionRepository>((Ref ref) {
  return SqliteSessionRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final settingsRepositoryProvider = Provider<SettingsRepository>((Ref ref) {
  return SqliteSettingsRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final cloudAuthSessionServiceProvider = Provider<CloudAuthSessionService>((
  Ref ref,
) {
  return CloudAuthSessionService(
    apiBaseUrl: ref.watch(envConfigProvider).apiBaseUrl,
    settings: ref.watch(settingsRepositoryProvider),
  );
});

AccessContext _access(Ref ref) => ref.read(accessHolderProvider).value;

final businessRepositoryProvider = Provider<BusinessRepository>((Ref ref) {
  return SqliteBusinessRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final activeBusinessIdProvider = FutureProvider<String>((Ref ref) {
  return ref.watch(businessRepositoryProvider).ensureActive();
});

final productRepositoryProvider = Provider<ProductRepository>((Ref ref) {
  return GuardedProductRepository(
    inner: SqliteProductRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final stockRepositoryProvider = Provider<StockRepository>((Ref ref) {
  return GuardedStockRepository(
    inner: SqliteStockRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final transactionRepositoryProvider = Provider<TransactionRepository>((
  Ref ref,
) {
  return GuardedTransactionRepository(
    inner: SqliteTransactionRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final posCartRepositoryProvider = Provider<PosCartRepository>((Ref ref) {
  return GuardedPosCartRepository(
    inner: SqlitePosCartRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final categoryRepositoryProvider = Provider<CategoryRepository>((Ref ref) {
  return GuardedCategoryRepository(
    inner: SqliteCategoryRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final customerRepositoryProvider = Provider<CustomerRepository>((Ref ref) {
  return GuardedCustomerRepository(
    inner: SqliteCustomerRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final supplierRepositoryProvider = Provider<SupplierRepository>((Ref ref) {
  return GuardedSupplierRepository(
    inner: SqliteSupplierRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((Ref ref) {
  return GuardedExpenseRepository(
    inner: SqliteExpenseRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final cashRepositoryProvider = Provider<CashRepository>((Ref ref) {
  return GuardedCashRepository(
    inner: SqliteCashRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final sqliteSyncRepositoryProvider = Provider<SqliteSyncRepository>((Ref ref) {
  return SqliteSyncRepository(
    database: ref.watch(appDatabaseProvider),
    clock: ref.watch(clockProvider),
  );
});

final syncRepositoryProvider = Provider<SyncRepository>((Ref ref) {
  return GuardedSyncRepository(
    inner: ref.watch(sqliteSyncRepositoryProvider),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final cloudSyncGatewayProvider = Provider<CloudSyncGateway>((Ref ref) {
  return HttpCloudSyncGateway(
    apiBaseUrl: ref.watch(envConfigProvider).apiBaseUrl,
    readAccessToken: () => ref
        .read(cloudAuthSessionServiceProvider)
        .readAccessToken(),
  );
});

final connectivityPortProvider = Provider<ConnectivityPort>((Ref ref) {
  return HttpConnectivityPort(
    apiBaseUrl: ref.watch(envConfigProvider).apiBaseUrl,
  );
});

final syncEngineProvider = Provider<SyncEngine>((Ref ref) {
  return SyncEngine(
    store: ref.watch(sqliteSyncRepositoryProvider),
    gateway: ref.watch(cloudSyncGatewayProvider),
    connectivity: ref.watch(connectivityPortProvider),
    loader: SyncSnapshotLoader(ref.watch(appDatabaseProvider)),
    subscriptions: ref.watch(subscriptionServiceProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
});

final sqliteSubscriptionRepositoryProvider =
    Provider<SqliteSubscriptionRepository>((Ref ref) {
      return SqliteSubscriptionRepository(
        database: ref.watch(appDatabaseProvider),
        clock: ref.watch(clockProvider),
      );
    });

final entitlementRepositoryProvider = Provider<EntitlementRepository>((
  Ref ref,
) {
  return ref.watch(sqliteSubscriptionRepositoryProvider);
});

final paymentHistoryRepositoryProvider = Provider<PaymentHistoryRepository>((
  Ref ref,
) {
  return ref.watch(sqliteSubscriptionRepositoryProvider);
});

final subscriptionConfigProvider = Provider<SubscriptionConfig>((Ref ref) {
  return ref.watch(appConfigProvider).subscription;
});

final billingGatewayProvider = Provider<BillingGateway>((Ref ref) {
  return HttpBillingGateway(
    apiBaseUrl: ref.watch(envConfigProvider).apiBaseUrl,
    readAccessToken: () => ref
        .read(cloudAuthSessionServiceProvider)
        .readAccessToken(),
  );
});

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((
  Ref ref,
) {
  return GuardedSubscriptionRepository(
    inner: ref.watch(sqliteSubscriptionRepositoryProvider),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final subscriptionServiceProvider = Provider<SubscriptionService>((Ref ref) {
  return SubscriptionService(
    store: ref.watch(sqliteSubscriptionRepositoryProvider),
    entitlements: ref.watch(entitlementRepositoryProvider),
    payments: ref.watch(paymentHistoryRepositoryProvider),
    billing: ref.watch(billingGatewayProvider),
    config: ref.watch(subscriptionConfigProvider),
    clock: ref.watch(clockProvider),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((Ref ref) {
  return GuardedDashboardRepository(
    inner: SqliteDashboardRepository(database: ref.watch(appDatabaseProvider)),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final reportRepositoryProvider = Provider<ReportRepository>((Ref ref) {
  return GuardedReportRepository(
    inner: SqliteReportRepository(database: ref.watch(appDatabaseProvider)),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final bluetoothPrinterPortProvider = Provider<BluetoothPrinterPort>((Ref ref) {
  return const PrintBluetoothThermalPort();
});

final printerRepositoryProvider = Provider<PrinterRepository>((Ref ref) {
  return GuardedPrinterRepository(
    inner: SqlitePrinterRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final storeRepositoryProvider = Provider<StoreRepository>((Ref ref) {
  return GuardedStoreRepository(
    inner: SqliteStoreRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
      documentsDirectory: getApplicationDocumentsDirectory,
    ),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final logoPickerProvider = Provider<LogoPicker>((Ref ref) {
  return ImagePickerLogoPicker();
});

final printerServiceProvider = Provider<PrinterService>((Ref ref) {
  return PrinterService(
    repository: ref.watch(printerRepositoryProvider),
    port: ref.watch(bluetoothPrinterPortProvider),
    transactions: ref.watch(transactionRepositoryProvider),
    storeRepository: ref.watch(storeRepositoryProvider),
  );
});

final backupGatewayProvider = Provider<BackupGateway>((Ref ref) {
  return HttpBackupGateway(
    apiBaseUrl: ref.watch(envConfigProvider).apiBaseUrl,
    readAccessToken: () => ref
        .read(cloudAuthSessionServiceProvider)
        .readAccessToken(),
  );
});

final backupServiceProvider = Provider<BackupService>((Ref ref) {
  return BackupService(
    builder: BackupSnapshotBuilder(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    restorer: BackupRestorer(ref.watch(appDatabaseProvider)),
    gateway: ref.watch(backupGatewayProvider),
    logs: SqliteBackupLogRepository(
      database: ref.watch(appDatabaseProvider),
      clock: ref.watch(clockProvider),
    ),
    subscriptions: ref.watch(subscriptionServiceProvider),
    connectivity: ref.watch(connectivityPortProvider),
    settings: ref.watch(settingsRepositoryProvider),
    guard: ref.watch(permissionGuardProvider),
    access: () => _access(ref),
  );
});

final cameraPermissionPortProvider = Provider<CameraPermissionPort>((Ref ref) {
  return const PermissionHandlerCameraPort();
});

final barcodeLookupServiceProvider = Provider<BarcodeLookupService>((Ref ref) {
  return BarcodeLookupService(products: ref.watch(productRepositoryProvider));
});
