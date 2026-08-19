import 'package:kasir_dapur/features/products/domain/product.dart';

final class CatalogImportResult {
  const CatalogImportResult({
    required this.created,
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  final int created;
  final int updated;
  final int skipped;
  final List<String> errors;

  int get imported => created + updated;
}

abstract class ProductRepository {
  Future<Product> create(NewProduct input);
  Future<Product> update(Product product);
  Future<Product?> getById(String id);
  Future<Product?> findByBarcode({
    required String businessId,
    required String barcode,
  });
  Future<Product?> findBySku({required String businessId, required String sku});
  Future<List<Product>> search({required String businessId, String query = ''});
  Future<List<ProductCatalogItem>> listCatalog({
    required String businessId,
    String query = '',
    String? categoryId,
    ProductListFilter filter = ProductListFilter.available,
  });
  Future<void> softDelete(String id);
  Future<void> restore(String id);
  Future<bool> hasTransactionHistory(String id);
  Future<void> setStock({
    required String productId,
    required String businessId,
    required int qty,
  });
  Future<CatalogImportResult> importCsv({
    required String businessId,
    required String csv,
  });
  Future<String> exportCsv({required String businessId});
}
