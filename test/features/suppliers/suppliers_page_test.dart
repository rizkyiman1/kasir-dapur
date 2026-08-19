import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier_repository.dart';
import 'package:kasir_dapur/features/suppliers/presentation/supplier_editor_page.dart';
import 'package:kasir_dapur/features/suppliers/presentation/supplier_history_page.dart';
import 'package:kasir_dapur/features/suppliers/presentation/suppliers_controller.dart';
import 'package:kasir_dapur/features/suppliers/presentation/suppliers_page.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );
  const Supplier beras = Supplier(
    id: 'sup-1',
    businessId: 'biz-1',
    name: 'CV Beras Jaya',
    contact: '081298765432',
    address: 'Pasar Induk',
    createdAt: 1,
    updatedAt: 1,
  );

  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  testWidgets('daftar pemasok: search, tambah, history', (tester) async {
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
          suppliersListProvider.overrideWith(
            (Ref ref) async => const <Supplier>[beras],
          ),
          supplierHistoryProvider.overrideWith(
            (Ref ref, String id) async => const <ContactHistoryEntry>[],
          ),
        ],
        child: const MaterialApp(home: SuppliersPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cari nama atau kontak'), findsOneWidget);
    expect(find.text('Tambah'), findsOneWidget);
    expect(find.text('CV Beras Jaya'), findsOneWidget);
    expect(find.text('081298765432'), findsOneWidget);
    expect(find.text('Email'), findsNothing);

    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    expect(find.textContaining('History'), findsOneWidget);
    expect(find.text('ID: sup-1'), findsOneWidget);
  });

  testWidgets('form pemasok memakai kontak, bukan email', (tester) async {
    final _FakeSupplierRepository repo = _FakeSupplierRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => SeededAuthController(user: owner),
          ),
          activeBusinessIdProvider.overrideWith((Ref ref) async => 'biz-1'),
          supplierRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: SupplierEditorPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nama'), findsOneWidget);
    expect(find.text('Kontak'), findsOneWidget);
    expect(find.text('Alamat'), findsOneWidget);
    expect(find.text('Catatan'), findsOneWidget);
    expect(find.text('Email'), findsNothing);
    expect(find.text('Nomor HP'), findsNothing);
    expect(find.textContaining('Tidak perlu email'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'UD Gula');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(repo.created?.name, 'UD Gula');
  });

  testWidgets('history pemasok menampilkan catatan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          supplierHistoryProvider.overrideWith(
            (Ref ref, String id) async => const <ContactHistoryEntry>[
              ContactHistoryEntry(
                id: 'h1',
                businessId: 'biz-1',
                partyType: ContactParty.supplier,
                partyId: 'sup-1',
                event: ContactEvent.created,
                summary: 'Pemasok ditambahkan',
                createdAt: 1755514800000,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: SupplierHistoryPage(supplier: beras)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pemasok ditambahkan'), findsOneWidget);
    expect(find.byTooltip('Tambah catatan'), findsOneWidget);
  });
}

final class _FakeSupplierRepository implements SupplierRepository {
  NewSupplier? created;

  @override
  Future<Supplier> create(NewSupplier input) async {
    created = input;
    return Supplier(
      id: 'new-1',
      businessId: input.businessId,
      name: input.name,
      contact: input.contact,
      address: input.address,
      notes: input.notes,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Future<Supplier> update(Supplier supplier) async => supplier;

  @override
  Future<Supplier?> getById(String id) async => null;

  @override
  Future<List<Supplier>> search({
    required String businessId,
    String query = '',
  }) async => const <Supplier>[];

  @override
  Future<List<ContactHistoryEntry>> history(String supplierId) async =>
      const <ContactHistoryEntry>[];

  @override
  Future<ContactHistoryEntry> addHistoryNote({
    required String supplierId,
    required String note,
  }) async {
    return ContactHistoryEntry(
      id: 'n1',
      businessId: 'biz-1',
      partyType: ContactParty.supplier,
      partyId: supplierId,
      event: ContactEvent.note,
      summary: note,
      createdAt: 1,
    );
  }

  @override
  Future<void> softDelete(String id) async {}
}
