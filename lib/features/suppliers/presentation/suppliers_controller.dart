import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';

final supplierQueryProvider = StateProvider<String>((Ref ref) => '');

final suppliersListProvider = FutureProvider<List<Supplier>>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  final String query = ref.watch(supplierQueryProvider);
  return ref
      .watch(supplierRepositoryProvider)
      .search(businessId: businessId, query: query);
});

final supplierHistoryProvider =
    FutureProvider.family<List<ContactHistoryEntry>, String>((
      Ref ref,
      String supplierId,
    ) {
      return ref.watch(supplierRepositoryProvider).history(supplierId);
    });

final class SupplierController {
  SupplierController(this._ref);

  final Ref _ref;

  Future<Supplier> save({
    required String businessId,
    Supplier? existing,
    required String name,
    String? contact,
    String? address,
    String? notes,
  }) async {
    final repo = _ref.read(supplierRepositoryProvider);
    final Supplier saved;
    if (existing == null) {
      saved = await repo.create(
        NewSupplier(
          businessId: businessId,
          name: name,
          contact: contact,
          address: address,
          notes: notes,
        ),
      );
    } else {
      saved = await repo.update(
        existing.copyWith(
          name: name,
          contact: contact,
          clearContact: contact == null || contact.trim().isEmpty,
          address: address,
          clearAddress: address == null || address.trim().isEmpty,
          notes: notes,
          clearNotes: notes == null || notes.trim().isEmpty,
        ),
      );
    }
    _ref.invalidate(suppliersListProvider);
    _ref.invalidate(supplierHistoryProvider(saved.id));
    return saved;
  }

  Future<void> addNote({
    required String supplierId,
    required String note,
  }) async {
    await _ref
        .read(supplierRepositoryProvider)
        .addHistoryNote(supplierId: supplierId, note: note);
    _ref.invalidate(supplierHistoryProvider(supplierId));
  }
}

final supplierControllerProvider = Provider<SupplierController>((Ref ref) {
  return SupplierController(ref);
});
