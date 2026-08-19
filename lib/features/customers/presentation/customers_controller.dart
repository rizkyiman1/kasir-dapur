import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';

final customerQueryProvider = StateProvider<String>((Ref ref) => '');

final customersListProvider = FutureProvider<List<Customer>>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  final String query = ref.watch(customerQueryProvider);
  return ref
      .watch(customerRepositoryProvider)
      .search(businessId: businessId, query: query);
});

final customerSalesHistoryProvider =
    FutureProvider.family<List<CustomerSaleHistory>, String>((
      Ref ref,
      String customerId,
    ) {
      return ref.watch(customerRepositoryProvider).salesHistory(customerId);
    });

final customerProfileHistoryProvider =
    FutureProvider.family<List<ContactHistoryEntry>, String>((
      Ref ref,
      String customerId,
    ) {
      return ref.watch(customerRepositoryProvider).profileHistory(customerId);
    });

final class CustomerController {
  CustomerController(this._ref);

  final Ref _ref;

  Future<Customer> save({
    required String businessId,
    Customer? existing,
    required String name,
    String? phone,
    String? address,
    String? notes,
  }) async {
    final repo = _ref.read(customerRepositoryProvider);
    final Customer saved;
    if (existing == null) {
      saved = await repo.create(
        NewCustomer(
          businessId: businessId,
          name: name,
          phone: phone,
          address: address,
          notes: notes,
        ),
      );
    } else {
      saved = await repo.update(
        existing.copyWith(
          name: name,
          phone: phone,
          clearPhone: phone == null || phone.trim().isEmpty,
          address: address,
          clearAddress: address == null || address.trim().isEmpty,
          notes: notes,
          clearNotes: notes == null || notes.trim().isEmpty,
        ),
      );
    }
    _ref.invalidate(customersListProvider);
    _ref.invalidate(customerProfileHistoryProvider(saved.id));
    return saved;
  }
}

final customerControllerProvider = Provider<CustomerController>((Ref ref) {
  return CustomerController(ref);
});
