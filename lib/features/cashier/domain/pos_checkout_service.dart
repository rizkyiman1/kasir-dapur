import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart_repository.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/features/transactions/domain/transaction_repository.dart';

/// Checkout kasir: penjualan atomic + hapus draft. Idempoten lewat client_uuid.
final class PosCheckoutService {
  const PosCheckoutService({required this._transactions, required this._carts});

  final TransactionRepository _transactions;
  final PosCartRepository _carts;

  Future<PosCart> restoreOpen({
    required String businessId,
    String? userId,
  }) async {
    final PosCart cart = await _carts.loadOrCreateOpen(
      businessId: businessId,
      userId: userId,
    );
    final Sale? existing = await _transactions.findByClientUuid(
      businessId: businessId,
      clientUuid: cart.clientUuid,
    );
    if (existing == null || existing.status != 'completed') {
      return cart;
    }
    await _carts.delete(cart.id);
    return _carts.loadOrCreateOpen(businessId: businessId, userId: userId);
  }

  Future<Sale> checkout({
    required PosCart cart,
    required List<SalePaymentDraft> payments,
    String? userId,
    String? cashSessionId,
  }) async {
    if (cart.isEmpty) {
      throw const ValidationException('Keranjang tidak boleh kosong');
    }
    if (cart.discountAmount > cart.subtotal) {
      throw const ValidationException(
        'Diskon transaksi tidak boleh melebihi subtotal',
      );
    }
    for (final CartLine line in cart.lines) {
      if (line.qty <= 0) {
        throw const ValidationException('Kuantitas harus lebih dari 0');
      }
      if (line.discountAmount > line.gross) {
        throw const ValidationException(
          'Diskon item tidak boleh melebihi harga baris',
        );
      }
    }
    final Sale sale = await _transactions.createCompletedSale(
      NewSale(
        businessId: cart.businessId,
        clientUuid: cart.clientUuid,
        userId: userId ?? cart.userId,
        customerId: cart.customerId,
        cashSessionId: cashSessionId,
        discountAmount: cart.discountAmount,
        note: cart.note,
        items: cart.lines
            .map(
              (CartLine line) => SaleItemDraft(
                productId: line.productId,
                qty: line.qty,
                discountAmount: line.discountAmount,
              ),
            )
            .toList(),
        payments: payments,
      ),
    );
    await _carts.delete(cart.id);
    return sale;
  }
}
