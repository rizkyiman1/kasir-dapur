final class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.businessId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
}

abstract class CategoryRepository {
  Future<CatalogCategory> create({
    required String businessId,
    required String name,
  });
  Future<CatalogCategory> rename({required String id, required String name});
  Future<List<CatalogCategory>> list({required String businessId});
  Future<void> archive(String id);
}

final class CatalogUnit {
  const CatalogUnit({
    required this.id,
    required this.businessId,
    required this.name,
    this.symbol,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  final String id;
  final String businessId;
  final String name;
  final String? symbol;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;
}

abstract class UnitRepository {
  Future<CatalogUnit> create({
    required String businessId,
    required String name,
    String? symbol,
  });
  Future<List<CatalogUnit>> list({required String businessId});
  Future<void> archive(String id);
}

abstract class BusinessRepository {
  Future<String?> activeId();
  Future<String> ensureActive();
}
