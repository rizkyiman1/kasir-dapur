import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';

enum InventoryListFilter { all, lowStock }

final inventoryQueryProvider = StateProvider<String>((Ref ref) => '');

final inventoryListFilterProvider = StateProvider<InventoryListFilter>(
  (Ref ref) => InventoryListFilter.all,
);

final inventoryPositionsProvider = FutureProvider<List<StockPosition>>((
  Ref ref,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  final String query = ref.watch(inventoryQueryProvider);
  final InventoryListFilter filter = ref.watch(inventoryListFilterProvider);
  return ref
      .watch(stockRepositoryProvider)
      .listPositions(
        businessId: businessId,
        query: query,
        lowStockOnly: filter == InventoryListFilter.lowStock,
      );
});

final allowNegativeStockProvider = FutureProvider<bool>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(stockRepositoryProvider).allowNegativeStock(businessId);
});

final stockHistoryProvider = FutureProvider<List<StockMovement>>((
  Ref ref,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(stockRepositoryProvider).listHistory(businessId: businessId);
});

final stockCardProvider = FutureProvider.family<List<StockMovement>, String>((
  Ref ref,
  String productId,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref
      .watch(stockRepositoryProvider)
      .listMovements(businessId: businessId, productId: productId);
});
