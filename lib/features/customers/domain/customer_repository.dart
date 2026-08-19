import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';

abstract class CustomerRepository {
  Future<Customer> create(NewCustomer input);
  Future<Customer> update(Customer customer);
  Future<Customer?> getById(String id);
  Future<List<Customer>> search({
    required String businessId,
    String query = '',
  });
  Future<List<CustomerSaleHistory>> salesHistory(String customerId);
  Future<List<ContactHistoryEntry>> profileHistory(String customerId);
  Future<void> softDelete(String id);
}
