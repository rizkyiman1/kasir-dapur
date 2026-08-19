import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/permissions/guarded_repositories.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/customers/data/customer_repository_impl.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/suppliers/data/supplier_repository_impl.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';
import 'package:kasir_dapur/features/transactions/data/transaction_repository_impl.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

import '../../helpers/pos_fixture.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;
  late String businessId;
  late SqliteCustomerRepository customers;
  late SqliteSupplierRepository suppliers;
  const ClockService clock = ClockService();

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kasir_dapur_crm_');
    database = AppDatabase(
      factory: databaseFactoryFfi,
      filePath: p.join(tempDir.path, 'kasir_dapur.db'),
    );
    businessId = await insertBusiness(await database.database, clock: clock);
    customers = SqliteCustomerRepository(database: database, clock: clock);
    suppliers = SqliteSupplierRepository(database: database, clock: clock);
  });

  tearDown(() async {
    await database.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'pelanggan search, edit, total transaksi, dan history penjualan',
    () async {
      final Customer created = await customers.create(
        NewCustomer(
          businessId: businessId,
          name: 'Siti',
          phone: '081234567890',
          address: 'Jl. Melati',
          notes: 'Langganan nasi',
        ),
      );
      expect(created.email, isNull);
      expect(created.transactionCount, 0);
      expect(created.spendTotal, 0);
      expect(
        (await customers.search(
          businessId: businessId,
          query: '0812',
        )).single.id,
        created.id,
      );

      final Customer renamed = await customers.update(
        created.copyWith(name: 'Siti Rahma', phone: '081234567890'),
      );
      expect(renamed.name, 'Siti Rahma');
      expect(renamed.email, isNull);

      final SqliteProductRepository products = SqliteProductRepository(
        database: database,
        clock: clock,
      );
      final Product product = await products.create(
        NewProduct(
          businessId: businessId,
          name: 'Es Teh',
          sellPrice: 5000,
          costPrice: 2000,
          initialStock: 10,
        ),
      );
      final SqliteTransactionRepository transactions =
          SqliteTransactionRepository(database: database, clock: clock);
      await transactions.createCompletedSale(
        NewSale(
          businessId: businessId,
          clientUuid: const Uuid().v4(),
          customerId: created.id,
          items: <SaleItemDraft>[SaleItemDraft(productId: product.id, qty: 2)],
          payments: const <SalePaymentDraft>[
            SalePaymentDraft(method: 'cash', amount: 10000),
          ],
        ),
      );

      final Customer afterSale = (await customers.getById(created.id))!;
      expect(afterSale.transactionCount, 1);
      expect(afterSale.spendTotal, 10000);
      final List<CustomerSaleHistory> history = await customers.salesHistory(
        created.id,
      );
      expect(history, hasLength(1));
      expect(history.single.totalAmount, 10000);
      final List<ContactHistoryEntry> profile = await customers.profileHistory(
        created.id,
      );
      expect(
        profile.map((ContactHistoryEntry row) => row.event),
        containsAll(<String>[ContactEvent.created, ContactEvent.updated]),
      );
    },
  );

  test('pemasok search, edit, history, tanpa email', () async {
    final Supplier created = await suppliers.create(
      NewSupplier(
        businessId: businessId,
        name: 'CV Beras Jaya',
        contact: '081298765432',
        address: 'Pasar Induk',
        notes: 'Kirim pagi',
      ),
    );
    expect(created.contact, '081298765432');
    expect(
      (await suppliers.search(
        businessId: businessId,
        query: 'beras',
      )).single.id,
      created.id,
    );
    expect(
      (await suppliers.search(businessId: businessId, query: '0812')).single.id,
      created.id,
    );

    await suppliers.update(created.copyWith(name: 'CV Beras Jaya Utama'));
    await suppliers.addHistoryNote(
      supplierId: created.id,
      note: 'Kirim setiap Senin',
    );
    final List<ContactHistoryEntry> history = await suppliers.history(
      created.id,
    );
    expect(history.first.summary, 'Kirim setiap Senin');
    expect(
      history.map((ContactHistoryEntry row) => row.event),
      containsAll(<String>[
        ContactEvent.created,
        ContactEvent.updated,
        ContactEvent.note,
      ]),
    );
  });

  test('nama kosong ditolak; kasir tidak boleh kelola pemasok', () async {
    expect(
      () => customers.create(NewCustomer(businessId: businessId, name: ' ')),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => suppliers.create(NewSupplier(businessId: businessId, name: '')),
      throwsA(isA<ValidationException>()),
    );

    final GuardedSupplierRepository guarded = GuardedSupplierRepository(
      inner: suppliers,
      guard: PermissionGuard(),
      access: () => const StaticAccessContext(
        currentUser: AuthUser(
          id: 'c1',
          displayName: 'Cici',
          role: UserRole.cashier,
        ),
      ),
    );
    expect(
      () => guarded.create(
        NewSupplier(businessId: businessId, name: 'CV Terlarang'),
      ),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
