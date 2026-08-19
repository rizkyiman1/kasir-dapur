import 'package:kasir_dapur/features/transactions/domain/sale.dart';

abstract class TransactionRepository {
  Future<Sale> createCompletedSale(NewSale input);
  Future<Sale?> getById(String id);
  Future<Sale?> findByClientUuid({
    required String businessId,
    required String clientUuid,
  });
}
