final class StockBalance {
  const StockBalance({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.qty,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String productId;
  final int qty;
  final int createdAt;
  final int updatedAt;
}

enum StockMovementType {
  stockIn,
  stockOut,
  sale,
  saleReturn,
  purchase,
  adjustment,
  damaged,
  expired,
  transfer;

  String get storageValue {
    return switch (this) {
      StockMovementType.stockIn => 'stock_in',
      StockMovementType.stockOut => 'stock_out',
      StockMovementType.sale => 'sale',
      StockMovementType.saleReturn => 'sale_return',
      StockMovementType.purchase => 'purchase',
      StockMovementType.adjustment => 'adjustment',
      StockMovementType.damaged => 'damaged',
      StockMovementType.expired => 'expired',
      StockMovementType.transfer => 'transfer',
    };
  }

  String get label {
    return switch (this) {
      StockMovementType.stockIn => 'Stok masuk',
      StockMovementType.stockOut => 'Stok keluar',
      StockMovementType.sale => 'Penjualan',
      StockMovementType.saleReturn => 'Retur penjualan',
      StockMovementType.purchase => 'Pembelian',
      StockMovementType.adjustment => 'Penyesuaian',
      StockMovementType.damaged => 'Rusak',
      StockMovementType.expired => 'Kadaluarsa',
      StockMovementType.transfer => 'Transfer',
    };
  }

  static StockMovementType parse(String value) {
    return switch (value) {
      'stock_in' || 'in' => StockMovementType.stockIn,
      'stock_out' || 'out' => StockMovementType.stockOut,
      'sale' => StockMovementType.sale,
      'sale_return' || 'return' || 'retur' => StockMovementType.saleReturn,
      'purchase' => StockMovementType.purchase,
      'adjustment' => StockMovementType.adjustment,
      'damaged' || 'damage' => StockMovementType.damaged,
      'expired' => StockMovementType.expired,
      'transfer' => StockMovementType.transfer,
      _ => throw FormatException('Jenis pergerakan stok tidak dikenal: $value'),
    };
  }

  static String labelFor(String storageValue) {
    try {
      return parse(storageValue).label;
    } on FormatException {
      return storageValue;
    }
  }
}

final class StockMovement {
  const StockMovement({
    required this.id,
    required this.businessId,
    required this.productId,
    required this.type,
    required this.qty,
    required this.qtyBefore,
    required this.qtyAfter,
    this.refType,
    this.refId,
    this.note,
    required this.createdAt,
    this.productName,
  });

  final String id;
  final String businessId;
  final String productId;
  final String type;
  final int qty;
  final int qtyBefore;
  final int qtyAfter;
  final String? refType;
  final String? refId;
  final String? note;
  final int createdAt;
  final String? productName;

  String get typeLabel => StockMovementType.labelFor(type);
}

final class StockPosition {
  const StockPosition({
    required this.productId,
    required this.businessId,
    required this.name,
    required this.qty,
    required this.minStock,
    required this.isActive,
    this.sku,
    this.barcode,
  });

  final String productId;
  final String businessId;
  final String name;
  final String? sku;
  final String? barcode;
  final int qty;
  final int minStock;
  final bool isActive;

  bool get isLow => minStock > 0 && qty <= minStock;
}

final class StockOpnameLine {
  const StockOpnameLine({required this.productId, required this.countedQty});

  final String productId;
  final int countedQty;
}

final class StockOpnameResult {
  const StockOpnameResult({
    required this.adjustedCount,
    required this.unchangedCount,
  });

  final int adjustedCount;
  final int unchangedCount;

  int get total => adjustedCount + unchangedCount;
}
