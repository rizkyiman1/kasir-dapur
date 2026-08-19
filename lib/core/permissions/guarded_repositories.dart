import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash_repository.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart_repository.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/customers/domain/customer_repository.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
import 'package:kasir_dapur/features/expenses/domain/expense_repository.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/inventory/domain/stock_repository.dart';
import 'package:kasir_dapur/features/printers/domain/printer_profile.dart';
import 'package:kasir_dapur/features/printers/domain/printer_repository.dart';
import 'package:kasir_dapur/features/products/domain/catalog_lookups.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/products/domain/product_repository.dart';
import 'package:kasir_dapur/features/settings/domain/store_profile.dart';
import 'package:kasir_dapur/features/settings/domain/store_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier_repository.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/features/sync/domain/sync_repository.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/features/transactions/domain/transaction_repository.dart';

final class GuardedProductRepository implements ProductRepository {
  GuardedProductRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final ProductRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _write() => _guard.require(_access(), AppPermission.manageProducts);

  void _read() => _guard.require(_access(), AppPermission.viewProducts);

  @override
  Future<Product> create(NewProduct input) {
    _write();
    return _inner.create(input);
  }

  @override
  Future<Product> update(Product product) {
    _write();
    return _inner.update(product);
  }

  @override
  Future<void> softDelete(String id) {
    _write();
    return _inner.softDelete(id);
  }

  @override
  Future<void> restore(String id) {
    _write();
    return _inner.restore(id);
  }

  @override
  Future<void> setStock({
    required String productId,
    required String businessId,
    required int qty,
  }) {
    _write();
    return _inner.setStock(
      productId: productId,
      businessId: businessId,
      qty: qty,
    );
  }

  @override
  Future<CatalogImportResult> importCsv({
    required String businessId,
    required String csv,
  }) {
    _write();
    return _inner.importCsv(businessId: businessId, csv: csv);
  }

  @override
  Future<String> exportCsv({required String businessId}) {
    _write();
    return _inner.exportCsv(businessId: businessId);
  }

  @override
  Future<Product?> getById(String id) {
    _read();
    return _inner.getById(id);
  }

  @override
  Future<Product?> findByBarcode({
    required String businessId,
    required String barcode,
  }) {
    _read();
    return _inner.findByBarcode(businessId: businessId, barcode: barcode);
  }

  @override
  Future<Product?> findBySku({
    required String businessId,
    required String sku,
  }) {
    _read();
    return _inner.findBySku(businessId: businessId, sku: sku);
  }

  @override
  Future<List<Product>> search({
    required String businessId,
    String query = '',
  }) {
    _read();
    return _inner.search(businessId: businessId, query: query);
  }

  @override
  Future<List<ProductCatalogItem>> listCatalog({
    required String businessId,
    String query = '',
    String? categoryId,
    ProductListFilter filter = ProductListFilter.available,
  }) {
    _read();
    return _inner.listCatalog(
      businessId: businessId,
      query: query,
      categoryId: categoryId,
      filter: filter,
    );
  }

  @override
  Future<bool> hasTransactionHistory(String id) {
    _read();
    return _inner.hasTransactionHistory(id);
  }
}

final class GuardedStockRepository implements StockRepository {
  GuardedStockRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final StockRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.manageStock);

  @override
  Future<StockBalance?> getByProduct({
    required String businessId,
    required String productId,
  }) {
    _require();
    return _inner.getByProduct(businessId: businessId, productId: productId);
  }

  @override
  Future<StockBalance> applyMovement({
    required String businessId,
    required String productId,
    required StockMovementType type,
    required int qtyDelta,
    String? refType,
    String? refId,
    String? note,
  }) {
    _require();
    return _inner.applyMovement(
      businessId: businessId,
      productId: productId,
      type: type,
      qtyDelta: qtyDelta,
      refType: refType,
      refId: refId,
      note: note,
    );
  }

  @override
  Future<StockBalance> stockIn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) {
    _require();
    return _inner.stockIn(
      businessId: businessId,
      productId: productId,
      qty: qty,
      note: note,
      refType: refType,
      refId: refId,
    );
  }

  @override
  Future<StockBalance> stockOut({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) {
    _require();
    return _inner.stockOut(
      businessId: businessId,
      productId: productId,
      qty: qty,
      note: note,
      refType: refType,
      refId: refId,
    );
  }

  @override
  Future<StockBalance> purchase({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) {
    _require();
    return _inner.purchase(
      businessId: businessId,
      productId: productId,
      qty: qty,
      note: note,
    );
  }

  @override
  Future<StockBalance> saleReturn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  }) {
    _require();
    return _inner.saleReturn(
      businessId: businessId,
      productId: productId,
      qty: qty,
      note: note,
      refType: refType,
      refId: refId,
    );
  }

  @override
  Future<StockBalance> recordDamaged({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) {
    _require();
    return _inner.recordDamaged(
      businessId: businessId,
      productId: productId,
      qty: qty,
      note: note,
    );
  }

  @override
  Future<StockBalance> recordExpired({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  }) {
    _require();
    return _inner.recordExpired(
      businessId: businessId,
      productId: productId,
      qty: qty,
      note: note,
    );
  }

  @override
  Future<StockBalance> transfer({
    required String businessId,
    required String productId,
    required int qtyDelta,
    String? note,
  }) {
    _require();
    return _inner.transfer(
      businessId: businessId,
      productId: productId,
      qtyDelta: qtyDelta,
      note: note,
    );
  }

  @override
  Future<StockBalance> adjustTo({
    required String businessId,
    required String productId,
    required int countedQty,
    String? note,
  }) {
    _require();
    return _inner.adjustTo(
      businessId: businessId,
      productId: productId,
      countedQty: countedQty,
      note: note,
    );
  }

  @override
  Future<List<StockMovement>> listMovements({
    required String businessId,
    required String productId,
  }) {
    _require();
    return _inner.listMovements(businessId: businessId, productId: productId);
  }

  @override
  Future<List<StockMovement>> listHistory({
    required String businessId,
    String? productId,
    StockMovementType? type,
    int limit = 200,
  }) {
    _require();
    return _inner.listHistory(
      businessId: businessId,
      productId: productId,
      type: type,
      limit: limit,
    );
  }

  @override
  Future<List<StockPosition>> listPositions({
    required String businessId,
    String query = '',
    bool lowStockOnly = false,
  }) {
    _require();
    return _inner.listPositions(
      businessId: businessId,
      query: query,
      lowStockOnly: lowStockOnly,
    );
  }

  @override
  Future<List<StockPosition>> listLowStock({required String businessId}) {
    _require();
    return _inner.listLowStock(businessId: businessId);
  }

  @override
  Future<StockOpnameResult> commitOpname({
    required String businessId,
    required List<StockOpnameLine> lines,
    String? note,
  }) {
    _require();
    return _inner.commitOpname(
      businessId: businessId,
      lines: lines,
      note: note,
    );
  }

  @override
  Future<bool> allowNegativeStock(String businessId) {
    _require();
    return _inner.allowNegativeStock(businessId);
  }

  @override
  Future<void> setAllowNegativeStock({
    required String businessId,
    required bool allow,
  }) {
    _require();
    return _inner.setAllowNegativeStock(businessId: businessId, allow: allow);
  }
}

final class GuardedTransactionRepository implements TransactionRepository {
  GuardedTransactionRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final TransactionRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  @override
  Future<Sale> createCompletedSale(NewSale input) {
    _guard.require(_access(), AppPermission.cashier);
    return _inner.createCompletedSale(input);
  }

  @override
  Future<Sale?> getById(String id) {
    _guard.require(_access(), AppPermission.viewTransactions);
    return _inner.getById(id);
  }

  @override
  Future<Sale?> findByClientUuid({
    required String businessId,
    required String clientUuid,
  }) {
    _guard.require(_access(), AppPermission.viewTransactions);
    return _inner.findByClientUuid(
      businessId: businessId,
      clientUuid: clientUuid,
    );
  }
}

final class GuardedCustomerRepository implements CustomerRepository {
  GuardedCustomerRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final CustomerRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.manageCustomers);

  @override
  Future<Customer> create(NewCustomer input) {
    _require();
    return _inner.create(input);
  }

  @override
  Future<Customer> update(Customer customer) {
    _require();
    return _inner.update(customer);
  }

  @override
  Future<Customer?> getById(String id) {
    _require();
    return _inner.getById(id);
  }

  @override
  Future<List<Customer>> search({
    required String businessId,
    String query = '',
  }) {
    _require();
    return _inner.search(businessId: businessId, query: query);
  }

  @override
  Future<List<CustomerSaleHistory>> salesHistory(String customerId) {
    _require();
    return _inner.salesHistory(customerId);
  }

  @override
  Future<List<ContactHistoryEntry>> profileHistory(String customerId) {
    _require();
    return _inner.profileHistory(customerId);
  }

  @override
  Future<void> softDelete(String id) {
    _require();
    return _inner.softDelete(id);
  }
}

final class GuardedSupplierRepository implements SupplierRepository {
  GuardedSupplierRepository({
    required SupplierRepository inner,
    required PermissionGuard guard,
    required AccessContext Function() access,
  }) : _inner = inner,
       _guard = guard,
       _access = access;

  final SupplierRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.manageSuppliers);

  @override
  Future<Supplier> create(NewSupplier input) {
    _require();
    return _inner.create(input);
  }

  @override
  Future<Supplier> update(Supplier supplier) {
    _require();
    return _inner.update(supplier);
  }

  @override
  Future<Supplier?> getById(String id) {
    _require();
    return _inner.getById(id);
  }

  @override
  Future<List<Supplier>> search({
    required String businessId,
    String query = '',
  }) {
    _require();
    return _inner.search(businessId: businessId, query: query);
  }

  @override
  Future<List<ContactHistoryEntry>> history(String supplierId) {
    _require();
    return _inner.history(supplierId);
  }

  @override
  Future<ContactHistoryEntry> addHistoryNote({
    required String supplierId,
    required String note,
  }) {
    _require();
    return _inner.addHistoryNote(supplierId: supplierId, note: note);
  }

  @override
  Future<void> softDelete(String id) {
    _require();
    return _inner.softDelete(id);
  }
}

final class GuardedExpenseRepository implements ExpenseRepository {
  GuardedExpenseRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final ExpenseRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.manageExpenses);

  @override
  Future<List<ExpenseCategory>> ensureDefaultCategories(String businessId) {
    _require();
    return _inner.ensureDefaultCategories(businessId);
  }

  @override
  Future<List<ExpenseCategory>> listCategories({required String businessId}) {
    _require();
    return _inner.listCategories(businessId: businessId);
  }

  @override
  Future<ExpenseCategory> createCategory({
    required String businessId,
    required String name,
    String? code,
  }) {
    _require();
    return _inner.createCategory(
      businessId: businessId,
      name: name,
      code: code,
    );
  }

  @override
  Future<Expense> create(NewExpense input) {
    _require();
    return _inner.create(input);
  }

  @override
  Future<List<Expense>> list({required String businessId, String? categoryId}) {
    _require();
    return _inner.list(businessId: businessId, categoryId: categoryId);
  }

  @override
  Future<void> softDelete(String id) {
    _require();
    return _inner.softDelete(id);
  }
}

final class GuardedCashRepository implements CashRepository {
  GuardedCashRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final CashRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.manageCash);

  @override
  Future<CashSession> openSession({
    required String businessId,
    required int openingAmount,
    String? userId,
  }) {
    _require();
    return _inner.openSession(
      businessId: businessId,
      openingAmount: openingAmount,
      userId: userId,
    );
  }

  @override
  Future<CashMovement> addMovement({
    required String sessionId,
    required String type,
    required int amount,
    String? note,
  }) {
    _require();
    return _inner.addMovement(
      sessionId: sessionId,
      type: type,
      amount: amount,
      note: note,
    );
  }

  @override
  Future<CashSession> closeSession({
    required String sessionId,
    required int countedAmount,
  }) {
    _require();
    return _inner.closeSession(
      sessionId: sessionId,
      countedAmount: countedAmount,
    );
  }

  @override
  Future<CashSession?> getOpenSession(String businessId) {
    _require();
    return _inner.getOpenSession(businessId);
  }

  @override
  Future<CashSession?> getSession(String id) {
    _require();
    return _inner.getSession(id);
  }

  @override
  Future<CashDrawerSnapshot> drawer(String sessionId) {
    _require();
    return _inner.drawer(sessionId);
  }

  @override
  Future<List<CashSession>> listClosed({
    required String businessId,
    int limit = 20,
  }) {
    _require();
    return _inner.listClosed(businessId: businessId, limit: limit);
  }
}

final class GuardedSyncRepository implements SyncRepository {
  GuardedSyncRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final SyncRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.manageSync);

  @override
  Future<SyncJob> enqueue({
    required String businessId,
    required String clientUuid,
    required String aggregate,
    required String operation,
    required String payload,
  }) {
    _require();
    return _inner.enqueue(
      businessId: businessId,
      clientUuid: clientUuid,
      aggregate: aggregate,
      operation: operation,
      payload: payload,
    );
  }

  @override
  Future<List<SyncJob>> pending({required String businessId}) {
    _require();
    return _inner.pending(businessId: businessId);
  }

  @override
  Future<List<SyncJob>> failed({required String businessId}) {
    _require();
    return _inner.failed(businessId: businessId);
  }

  @override
  Future<int> countByStatus({
    required String businessId,
    required String status,
  }) {
    return _inner.countByStatus(businessId: businessId, status: status);
  }

  @override
  Future<void> markSyncing(String id) {
    _require();
    return _inner.markSyncing(id);
  }

  @override
  Future<void> markDone(String id) {
    _require();
    return _inner.markDone(id);
  }

  @override
  Future<void> markFailed({required String id, required String error}) {
    _require();
    return _inner.markFailed(id: id, error: error);
  }

  @override
  Future<int> retryFailed(String businessId) {
    _require();
    return _inner.retryFailed(businessId);
  }

  @override
  Future<void> markPendingForRetry(String id) {
    _require();
    return _inner.markPendingForRetry(id);
  }

  @override
  Future<void> requeueStaleSyncing(String businessId) {
    return _inner.requeueStaleSyncing(businessId);
  }

  @override
  Future<List<SyncLog>> recentLogs({
    required String businessId,
    int limit = 20,
  }) {
    _require();
    return _inner.recentLogs(businessId: businessId, limit: limit);
  }

  @override
  Future<SyncLog> writeLog({
    required String businessId,
    String? queueId,
    required String direction,
    required String status,
    String? message,
  }) {
    _require();
    return _inner.writeLog(
      businessId: businessId,
      queueId: queueId,
      direction: direction,
      status: status,
      message: message,
    );
  }
}

final class GuardedSubscriptionRepository implements SubscriptionRepository {
  GuardedSubscriptionRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final SubscriptionRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() =>
      _guard.require(_access(), AppPermission.manageSubscription);

  @override
  Future<Subscription> upsertPlan({
    required String businessId,
    required Plan plan,
    required String source,
    required int startsAt,
    int? endsAt,
    BillingPlan? planCode,
    SubscriptionStatus status = SubscriptionStatus.active,
    int? graceEndsAt,
    String? provider,
    String? providerOrderId,
    int? verifiedAt,
    bool seedEntitlements = true,
    bool supersedeCurrent = true,
  }) {
    _require();
    return _inner.upsertPlan(
      businessId: businessId,
      plan: plan,
      source: source,
      startsAt: startsAt,
      endsAt: endsAt,
      planCode: planCode,
      status: status,
      graceEndsAt: graceEndsAt,
      provider: provider,
      providerOrderId: providerOrderId,
      verifiedAt: verifiedAt,
      seedEntitlements: seedEntitlements,
      supersedeCurrent: supersedeCurrent,
    );
  }

  @override
  Future<Subscription?> current(String businessId) {
    return _inner.current(businessId);
  }

  @override
  Future<Subscription?> latestPending(String businessId) {
    return _inner.latestPending(businessId);
  }

  @override
  Future<List<Subscription>> listSubscriptions(String businessId) {
    return _inner.listSubscriptions(businessId);
  }

  @override
  Future<void> updateStatus({
    required String id,
    required SubscriptionStatus status,
    int? graceEndsAt,
    int? lastSyncedAt,
  }) {
    _require();
    return _inner.updateStatus(
      id: id,
      status: status,
      graceEndsAt: graceEndsAt,
      lastSyncedAt: lastSyncedAt,
    );
  }

  @override
  Future<void> replaceEntitlements({
    required String businessId,
    required String subscriptionId,
    required Plan plan,
  }) {
    _require();
    return _inner.replaceEntitlements(
      businessId: businessId,
      subscriptionId: subscriptionId,
      plan: plan,
    );
  }
}

final class GuardedPosCartRepository implements PosCartRepository {
  GuardedPosCartRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final PosCartRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.cashier);

  @override
  Future<PosCart> loadOrCreateOpen({
    required String businessId,
    String? userId,
  }) {
    _require();
    return _inner.loadOrCreateOpen(businessId: businessId, userId: userId);
  }

  @override
  Future<PosCart> save(PosCart cart) {
    _require();
    return _inner.save(cart);
  }

  @override
  Future<PosCart> hold(PosCart cart) {
    _require();
    return _inner.hold(cart);
  }

  @override
  Future<List<PosCart>> listHeld({required String businessId}) {
    _require();
    return _inner.listHeld(businessId: businessId);
  }

  @override
  Future<PosCart> resume({
    required String id,
    required String businessId,
    String? userId,
  }) {
    _require();
    return _inner.resume(id: id, businessId: businessId, userId: userId);
  }

  @override
  Future<PosCart> cancel(PosCart cart) {
    _require();
    return _inner.cancel(cart);
  }

  @override
  Future<void> delete(String id) {
    _require();
    return _inner.delete(id);
  }

  @override
  Future<PosCart?> getById(String id) {
    _require();
    return _inner.getById(id);
  }
}

final class GuardedCategoryRepository implements CategoryRepository {
  GuardedCategoryRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final CategoryRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  @override
  Future<CatalogCategory> create({
    required String businessId,
    required String name,
  }) {
    _guard.require(_access(), AppPermission.manageProducts);
    return _inner.create(businessId: businessId, name: name);
  }

  @override
  Future<CatalogCategory> rename({required String id, required String name}) {
    _guard.require(_access(), AppPermission.manageProducts);
    return _inner.rename(id: id, name: name);
  }

  @override
  Future<List<CatalogCategory>> list({required String businessId}) {
    _guard.require(_access(), AppPermission.viewProducts);
    return _inner.list(businessId: businessId);
  }

  @override
  Future<void> archive(String id) {
    _guard.require(_access(), AppPermission.manageProducts);
    return _inner.archive(id);
  }
}

final class GuardedPrinterRepository implements PrinterRepository {
  GuardedPrinterRepository({
    required this._inner,
    required this._guard,
    required this._access,
  });

  final PrinterRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _require() => _guard.require(_access(), AppPermission.managePrinters);

  @override
  Future<PrinterProfile> loadOrCreate({required String businessId}) {
    _require();
    return _inner.loadOrCreate(businessId: businessId);
  }

  @override
  Future<PrinterProfile> save(PrinterProfile profile) {
    _require();
    return _inner.save(profile);
  }
}

final class GuardedStoreRepository implements StoreRepository {
  GuardedStoreRepository({
    required StoreRepository inner,
    required PermissionGuard guard,
    required AccessContext Function() access,
  }) : _inner = inner,
       _guard = guard,
       _access = access;

  final StoreRepository _inner;
  final PermissionGuard _guard;
  final AccessContext Function() _access;

  void _write() => _guard.require(_access(), AppPermission.manageSettings);

  @override
  Future<StoreProfile> getByBusinessId(String businessId) {
    return _inner.getByBusinessId(businessId);
  }

  @override
  Future<StoreProfile> update({
    required String businessId,
    required StoreProfilePatch patch,
  }) {
    _write();
    return _inner.update(businessId: businessId, patch: patch);
  }

  @override
  Future<StoreProfile> saveLogo({
    required String businessId,
    required String sourcePath,
  }) {
    _write();
    return _inner.saveLogo(businessId: businessId, sourcePath: sourcePath);
  }

  @override
  Future<StoreProfile> clearLogo(String businessId) {
    _write();
    return _inner.clearLogo(businessId);
  }
}
