import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';

abstract class SupplierRepository {
  Future<Supplier> create(NewSupplier input);
  Future<Supplier> update(Supplier supplier);
  Future<Supplier?> getById(String id);
  Future<List<Supplier>> search({
    required String businessId,
    String query = '',
  });
  Future<List<ContactHistoryEntry>> history(String supplierId);
  Future<ContactHistoryEntry> addHistoryNote({
    required String supplierId,
    required String note,
  });
  Future<void> softDelete(String id);
}
