import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';

abstract class PosCartRepository {
  Future<PosCart> loadOrCreateOpen({
    required String businessId,
    String? userId,
  });

  Future<PosCart> save(PosCart cart);

  Future<PosCart> hold(PosCart cart);

  Future<List<PosCart>> listHeld({required String businessId});

  Future<PosCart> resume({
    required String id,
    required String businessId,
    String? userId,
  });

  Future<PosCart> cancel(PosCart cart);

  Future<void> delete(String id);

  Future<PosCart?> getById(String id);
}
