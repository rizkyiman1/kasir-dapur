import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_checkout_service.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/products/domain/catalog_lookups.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';

final cashierQueryProvider = StateProvider<String>((Ref ref) => '');

final cashierCategoryIdProvider = StateProvider<String?>((Ref ref) => null);

final cashierCatalogProvider = FutureProvider<List<ProductCatalogItem>>((
  Ref ref,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref
      .watch(productRepositoryProvider)
      .listCatalog(
        businessId: businessId,
        query: ref.watch(cashierQueryProvider),
        categoryId: ref.watch(cashierCategoryIdProvider),
        filter: ProductListFilter.active,
      );
});

final cashierCategoriesProvider = FutureProvider<List<CatalogCategory>>((
  Ref ref,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(categoryRepositoryProvider).list(businessId: businessId);
});

final posHeldCartsProvider = FutureProvider<List<PosCart>>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(posCartRepositoryProvider).listHeld(businessId: businessId);
});

final posCartProvider = AsyncNotifierProvider<PosCartController, PosCart>(
  PosCartController.new,
);

final class PosCartController extends AsyncNotifier<PosCart> {
  Future<Sale>? _payInflight;

  PosCheckoutService get _checkout {
    return PosCheckoutService(
      transactions: ref.read(transactionRepositoryProvider),
      carts: ref.read(posCartRepositoryProvider),
    );
  }

  @override
  Future<PosCart> build() async {
    final String businessId = await ref.watch(activeBusinessIdProvider.future);
    final String? userId = ref.watch(authControllerProvider).user?.id;
    return _checkout.restoreOpen(businessId: businessId, userId: userId);
  }

  Future<void> addCatalogItem(ProductCatalogItem item) {
    return _mutate(
      (PosCart cart) => cart.addOrIncrement(
        CartLine(
          productId: item.product.id,
          name: item.product.name,
          unitPrice: item.product.sellPrice,
          costPrice: item.product.costPrice,
          qty: 1,
          sku: item.product.sku,
          barcode: item.product.barcode,
        ),
      ),
    );
  }

  Future<void> addProduct(Product product) {
    return _mutate(
      (PosCart cart) => cart.addOrIncrement(
        CartLine(
          productId: product.id,
          name: product.name,
          unitPrice: product.sellPrice,
          costPrice: product.costPrice,
          qty: 1,
          sku: product.sku,
          barcode: product.barcode,
        ),
      ),
    );
  }

  Future<void> setQty(String productId, int qty) {
    return _mutate((PosCart cart) => cart.setQty(productId, qty));
  }

  Future<void> removeLine(String productId) {
    return _mutate((PosCart cart) => cart.removeLine(productId));
  }

  Future<void> setItemDiscount(String productId, int amount) {
    return _mutate((PosCart cart) => cart.setItemDiscount(productId, amount));
  }

  Future<void> setTransactionDiscount(int amount) {
    return _mutate((PosCart cart) => cart.setTransactionDiscount(amount));
  }

  Future<void> setCustomer(Customer? customer) {
    return _mutate((PosCart cart) {
      if (customer == null) {
        return cart.copyWith(clearCustomer: true);
      }
      return cart.copyWith(
        customerId: customer.id,
        customerName: customer.name,
      );
    });
  }

  Future<void> hold() async {
    final PosCart? current = state.asData?.value;
    if (current == null) {
      return;
    }
    final PosCart held = await ref
        .read(posCartRepositoryProvider)
        .hold(current);
    final PosCart next = await ref
        .read(posCartRepositoryProvider)
        .loadOrCreateOpen(businessId: held.businessId, userId: held.userId);
    state = AsyncData<PosCart>(next);
    ref.invalidate(posHeldCartsProvider);
  }

  Future<void> resume(String id) async {
    final String businessId = await ref.read(activeBusinessIdProvider.future);
    final String? userId = ref.read(authControllerProvider).user?.id;
    final PosCart cart = await ref
        .read(posCartRepositoryProvider)
        .resume(id: id, businessId: businessId, userId: userId);
    state = AsyncData<PosCart>(cart);
    ref.invalidate(posHeldCartsProvider);
  }

  Future<void> cancelCurrent() async {
    final PosCart? current = state.asData?.value;
    if (current == null) {
      return;
    }
    final PosCart next = await ref
        .read(posCartRepositoryProvider)
        .cancel(current);
    state = AsyncData<PosCart>(next);
    ref.invalidate(posHeldCartsProvider);
  }

  Future<Sale> pay(List<SalePaymentDraft> payments) {
    final Future<Sale>? existing = _payInflight;
    if (existing != null) {
      return existing;
    }
    final Future<Sale> started = _pay(payments);
    _payInflight = started;
    return started.whenComplete(() {
      _payInflight = null;
    });
  }

  Future<Sale> _pay(List<SalePaymentDraft> payments) async {
    final PosCart cart = await future;
    final String? userId = ref.read(authControllerProvider).user?.id;
    String? cashSessionId;
    try {
      cashSessionId =
          (await ref
                  .read(cashRepositoryProvider)
                  .getOpenSession(cart.businessId))
              ?.id;
    } on Object {
      cashSessionId = null;
    }
    final Sale sale = await _checkout.checkout(
      cart: cart,
      payments: payments,
      userId: userId,
      cashSessionId: cashSessionId,
    );
    final PosCart next = await ref
        .read(posCartRepositoryProvider)
        .loadOrCreateOpen(businessId: cart.businessId, userId: userId);
    state = AsyncData<PosCart>(next);
    ref.invalidate(cashierCatalogProvider);
    unawaited(_kickSync(cart.businessId));
    return sale;
  }

  Future<void> _kickSync(String businessId) async {
    try {
      await ref.read(syncEngineProvider).run(businessId: businessId);
    } on Object {
      // Pembayaran sudah tersimpan di SQLite. Antrian menunggu percobaan berikutnya.
    }
  }

  Future<void> _mutate(PosCart Function(PosCart cart) update) async {
    final PosCart current = await future;
    final PosCart saved = await ref
        .read(posCartRepositoryProvider)
        .save(update(current));
    state = AsyncData<PosCart>(saved);
  }
}
