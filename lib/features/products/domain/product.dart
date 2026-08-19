final class Product {
  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    this.categoryId,
    this.unitId,
    this.sku,
    this.barcode,
    required this.costPrice,
    required this.sellPrice,
    required this.minStock,
    required this.isActive,
    this.imagePath,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? categoryId;
  final String? unitId;
  final String? sku;
  final String? barcode;
  final int costPrice;
  final int sellPrice;
  final int minStock;
  final bool isActive;
  final String? imagePath;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  bool get isArchived => deletedAt != null;

  Product copyWith({
    String? name,
    String? categoryId,
    String? unitId,
    String? sku,
    String? barcode,
    int? costPrice,
    int? sellPrice,
    int? minStock,
    bool? isActive,
    String? imagePath,
    String? description,
    int? updatedAt,
    int? deletedAt,
    bool clearCategory = false,
    bool clearUnit = false,
    bool clearSku = false,
    bool clearBarcode = false,
    bool clearImage = false,
    bool clearDescription = false,
  }) {
    return Product(
      id: id,
      businessId: businessId,
      name: name ?? this.name,
      categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
      unitId: clearUnit ? null : (unitId ?? this.unitId),
      sku: clearSku ? null : (sku ?? this.sku),
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      minStock: minStock ?? this.minStock,
      isActive: isActive ?? this.isActive,
      imagePath: clearImage ? null : (imagePath ?? this.imagePath),
      description: clearDescription ? null : (description ?? this.description),
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}

final class NewProduct {
  const NewProduct({
    required this.businessId,
    required this.name,
    this.categoryId,
    this.unitId,
    this.sku,
    this.barcode,
    this.costPrice = 0,
    this.sellPrice = 0,
    this.minStock = 0,
    this.initialStock = 0,
    this.isActive = true,
    this.imagePath,
    this.description,
  });

  final String businessId;
  final String name;
  final String? categoryId;
  final String? unitId;
  final String? sku;
  final String? barcode;
  final int costPrice;
  final int sellPrice;
  final int minStock;
  final int initialStock;
  final bool isActive;
  final String? imagePath;
  final String? description;
}

final class ProductCatalogItem {
  const ProductCatalogItem({
    required this.product,
    required this.stockQty,
    this.categoryName,
    this.unitName,
  });

  final Product product;
  final int stockQty;
  final String? categoryName;
  final String? unitName;
}

enum ProductListFilter {
  available,
  active,
  inactive,
  archived;

  String get label {
    return switch (this) {
      ProductListFilter.available => 'Semua',
      ProductListFilter.active => 'Aktif',
      ProductListFilter.inactive => 'Nonaktif',
      ProductListFilter.archived => 'Arsip',
    };
  }
}
