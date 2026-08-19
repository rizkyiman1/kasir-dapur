import 'package:kasir_dapur/features/inventory/domain/stock.dart';

abstract class StockRepository {
  Future<StockBalance?> getByProduct({
    required String businessId,
    required String productId,
  });

  Future<StockBalance> applyMovement({
    required String businessId,
    required String productId,
    required StockMovementType type,
    required int qtyDelta,
    String? refType,
    String? refId,
    String? note,
  });

  Future<StockBalance> stockIn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  });

  Future<StockBalance> stockOut({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  });

  Future<StockBalance> purchase({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  });

  Future<StockBalance> saleReturn({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
    String? refType,
    String? refId,
  });

  Future<StockBalance> recordDamaged({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  });

  Future<StockBalance> recordExpired({
    required String businessId,
    required String productId,
    required int qty,
    String? note,
  });

  Future<StockBalance> transfer({
    required String businessId,
    required String productId,
    required int qtyDelta,
    String? note,
  });

  Future<StockBalance> adjustTo({
    required String businessId,
    required String productId,
    required int countedQty,
    String? note,
  });

  Future<List<StockMovement>> listMovements({
    required String businessId,
    required String productId,
  });

  Future<List<StockMovement>> listHistory({
    required String businessId,
    String? productId,
    StockMovementType? type,
    int limit = 200,
  });

  Future<List<StockPosition>> listPositions({
    required String businessId,
    String query = '',
    bool lowStockOnly = false,
  });

  Future<List<StockPosition>> listLowStock({required String businessId});

  Future<StockOpnameResult> commitOpname({
    required String businessId,
    required List<StockOpnameLine> lines,
    String? note,
  });

  Future<bool> allowNegativeStock(String businessId);

  Future<void> setAllowNegativeStock({
    required String businessId,
    required bool allow,
  });
}
