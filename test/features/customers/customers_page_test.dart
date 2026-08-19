import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/customers/domain/customer_repository.dart';
import 'package:kasir_dapur/features/customers/presentation/customer_editor_page.dart';
import 'package:kasir_dapur/features/customers/presentation/customer_history_page.dart';
import 'package:kasir_dapur/features/customers/presentation/customers_controller.dart';
import 'package:kasir_dapur/features/customers/presentation/customers_page.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );
  const Customer siti = Customer(
    id: 'cust-1',
    businessId: 'biz-1',
    name: 'Siti',
    phone: '081234567890',
    address: 'Jl. Melati',
    transactionCount: 2,
    spendTotal: 15000,
    createdAt: 1,
    updatedAt: 1,
  );

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('daftar pelanggan: search, tambah, history, total belanja', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => SeededAuthController(user: owner),
          ),
          featureGateProvider.overrideWith(
            (Ref ref) async => FeatureGate.forPlan(Plan.pro),
          ),
          customersListProvider.overrideWith(
            (Ref ref) async => const <Customer>[siti],
          ),
          customerSalesHistoryProvider.overrideWith(
            (Ref ref, String id) async => const <CustomerSaleHistory>[],
          ),
        ],
        child: const MaterialApp(home: CustomersPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cari nama atau nomor HP'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
    expect(find.text('Siti'), findsOneWidget);
    expect(find.textContaining('2 transaksi'), findsOneWidget);
    expect(find.textContaining('Rp15.000'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('KTP'), findsNothing);

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('History'), findsOneWidget);
    expect(find.textContaining('Total transaksi'), findsOneWidget);
    expect(find.textContaining('Total belanja'), findsOneWidget);
  });

  testWidgets('form pelanggan tidak meminta email atau KTP', (tester) async {
    final _FakeCustomerRepository repo = _FakeCustomerRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => SeededAuthController(user: owner),
          ),
          featureGateProvider.overrideWith(
            (Ref ref) async => FeatureGate.forPlan(Plan.pro),
          ),
          activeBusinessIdProvider.overrideWith((Ref ref) async => 'biz-1'),
          customerRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: CustomerEditorPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nama'), findsOneWidget);
    expect(find.text('Nomor HP'), findsOneWidget);
    expect(find.text('Alamat'), findsOneWidget);
    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('KTP'), findsNothing);
    expect(find.textContaining('Tidak perlu email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Andi');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repo.created, isNotNull);
    expect(repo.created!.email, isNull);
    expect(repo.created!.name, 'Andi');
  });

  testWidgets('history pelanggan menampilkan penjualan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customerSalesHistoryProvider.overrideWith(
            (Ref ref, String id) async => const <CustomerSaleHistory>[
              CustomerSaleHistory(
                transactionId: 't1',
                status: 'completed',
                totalAmount: 15000,
                createdAt: 1755514800000,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: CustomerHistoryPage(customer: siti)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Total transaksi: 2'), findsOneWidget);
    expect(find.textContaining('Rp15.000'), findsWidgets);
  });
}

final class _FakeCustomerRepository implements CustomerRepository {
  NewCustomer? created;

  @override
  Future<Customer> create(NewCustomer input) async {
    created = input;
    return Customer(
      id: 'new-1',
      businessId: input.businessId,
      name: input.name,
      phone: input.phone,
      email: input.email,
      address: input.address,
      notes: input.notes,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Future<Customer> update(Customer customer) async => customer;

  @override
  Future<Customer?> getById(String id) async => null;

  @override
  Future<List<Customer>> search({
    required String businessId,
    String query = '',
  }) async => const <Customer>[];

  @override
  Future<List<CustomerSaleHistory>> salesHistory(String customerId) async =>
      const <CustomerSaleHistory>[];

  @override
  Future<List<ContactHistoryEntry>> profileHistory(String customerId) async =>
      const <ContactHistoryEntry>[];

  @override
  Future<void> softDelete(String id) async {}
}
