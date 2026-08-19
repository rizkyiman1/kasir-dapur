import 'dart:convert';

import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/inventory/data/stock_repository_impl.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/products/data/product_repository_impl.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:kasir_dapur/features/transactions/domain/sale.dart';
import 'package:kasir_dapur/features/transactions/domain/transaction_repository.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteTransactionRepository implements TransactionRepository {
  SqliteTransactionRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<Sale> createCompletedSale(NewSale input) async {
    if (input.items.isEmpty) {
      throw const ValidationException('Keranjang tidak boleh kosong');
    }
    if (input.payments.isEmpty) {
      throw const ValidationException('Pembayaran wajib diisi');
    }
    if (input.discountAmount < 0 || input.taxAmount < 0) {
      throw const ValidationException('Diskon dan pajak harus integer >= 0');
    }

    try {
      return await _database.runInTransaction((Transaction txn) async {
        final Sale? existing = await _findByClientUuid(
          txn,
          businessId: input.businessId,
          clientUuid: input.clientUuid,
        );
        if (existing != null) {
          return existing;
        }

        var subtotal = 0;
        final List<({SaleItemDraft draft, Product product, int lineTotal})>
        resolved = [];
        for (final SaleItemDraft draft in input.items) {
          if (draft.qty <= 0) {
            throw const ValidationException('Kuantitas harus lebih dari 0');
          }
          if (draft.discountAmount < 0) {
            throw const ValidationException('Diskon item tidak boleh negatif');
          }
          final Product? product = await _productById(txn, draft.productId);
          if (product == null) {
            throw const NotFoundException('Produk tidak ditemukan');
          }
          final int gross = product.sellPrice * draft.qty;
          final int lineTotal = gross - draft.discountAmount;
          if (lineTotal < 0) {
            throw const ValidationException('Total baris tidak boleh negatif');
          }
          subtotal += lineTotal;
          resolved.add((draft: draft, product: product, lineTotal: lineTotal));
        }

        final int total = subtotal - input.discountAmount + input.taxAmount;
        if (total < 0) {
          throw const ValidationException(
            'Total transaksi tidak boleh negatif',
          );
        }
        var paid = 0;
        for (final SalePaymentDraft payment in input.payments) {
          _assertPayment(payment);
          paid += payment.amount;
        }
        if (paid != total) {
          throw const ValidationException(
            'Jumlah pembayaran harus sama dengan total',
          );
        }

        final String saleId = _uuid.v4();
        final int now = _clock.nowEpochMs();
        await txn.insert(DatabaseConstants.tableTransactions, <String, Object?>{
          'id': saleId,
          'client_uuid': input.clientUuid,
          'business_id': input.businessId,
          'user_id': input.userId,
          'customer_id': input.customerId,
          'cash_session_id': input.cashSessionId,
          'status': 'completed',
          'subtotal_amount': subtotal,
          'discount_amount': input.discountAmount,
          'tax_amount': input.taxAmount,
          'total_amount': total,
          'note': input.note,
          'created_at': now,
          'updated_at': now,
        });

        for (final item in resolved) {
          await txn.insert(
            DatabaseConstants.tableTransactionItems,
            <String, Object>{
              'id': _uuid.v4(),
              'transaction_id': saleId,
              'product_id': item.product.id,
              'name_snapshot': item.product.name,
              'qty': item.draft.qty,
              'unit_price': item.product.sellPrice,
              'cost_price': item.product.costPrice,
              'discount_amount': item.draft.discountAmount,
              'line_total': item.lineTotal,
              'created_at': now,
              'updated_at': now,
            },
          );
          await applyStockDelta(
            txn,
            clock: _clock,
            uuid: _uuid,
            businessId: input.businessId,
            productId: item.product.id,
            type: StockMovementType.sale,
            qtyDelta: -item.draft.qty,
            refType: 'transaction',
            refId: saleId,
          );
        }

        for (final SalePaymentDraft payment in input.payments) {
          await txn.insert(DatabaseConstants.tablePayments, <String, Object>{
            'id': _uuid.v4(),
            'transaction_id': saleId,
            'method': payment.method,
            'amount': payment.amount,
            'tendered_amount': payment.tenderedAmount,
            'change_amount': payment.changeAmount,
            'created_at': now,
            'updated_at': now,
          });
        }

        await enqueueSync(
          txn,
          clock: _clock,
          uuid: _uuid,
          businessId: input.businessId,
          clientUuid: input.clientUuid,
          aggregate: 'transaction',
          operation: 'upsert',
          payload: jsonEncode(<String, String>{'id': saleId}),
        );

        return (await _getById(txn, saleId))!;
      });
    } catch (error) {
      if (_isDuplicateClientUuid(error)) {
        final Sale? recovered = await findByClientUuid(
          businessId: input.businessId,
          clientUuid: input.clientUuid,
        );
        if (recovered != null) {
          return recovered;
        }
      }
      rethrow;
    }
  }

  static bool _isDuplicateClientUuid(Object error) {
    final String text = error.toString();
    return text.contains('UNIQUE constraint failed') &&
        text.contains('client_uuid');
  }

  @override
  Future<Sale?> getById(String id) async {
    final Database db = await _database.database;
    return _getById(db, id);
  }

  @override
  Future<Sale?> findByClientUuid({
    required String businessId,
    required String clientUuid,
  }) async {
    final Database db = await _database.database;
    return _findByClientUuid(
      db,
      businessId: businessId,
      clientUuid: clientUuid,
    );
  }

  Future<Product?> _productById(DatabaseExecutor executor, String id) async {
    final rows = await executor.query(
      DatabaseConstants.tableProducts,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SqliteProductRepository.mapProduct(rows.first);
  }

  Future<Sale?> _findByClientUuid(
    DatabaseExecutor executor, {
    required String businessId,
    required String clientUuid,
  }) async {
    final rows = await executor.query(
      DatabaseConstants.tableTransactions,
      where: 'business_id = ? AND client_uuid = ?',
      whereArgs: <Object>[businessId, clientUuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _assemble(
      executor,
      readString(rows.first['id'], field: 'id'),
      rows.first,
    );
  }

  Future<Sale?> _getById(DatabaseExecutor executor, String id) async {
    final rows = await executor.query(
      DatabaseConstants.tableTransactions,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _assemble(executor, id, rows.first);
  }

  Future<Sale> _assemble(
    DatabaseExecutor executor,
    String id,
    Map<String, Object?> header,
  ) async {
    final itemRows = await executor.query(
      DatabaseConstants.tableTransactionItems,
      where: 'transaction_id = ?',
      whereArgs: <Object>[id],
    );
    final paymentRows = await executor.query(
      DatabaseConstants.tablePayments,
      where: 'transaction_id = ?',
      whereArgs: <Object>[id],
    );
    return Sale(
      id: id,
      clientUuid: readString(header['client_uuid'], field: 'client_uuid'),
      businessId: readString(header['business_id'], field: 'business_id'),
      userId: readStringOrNull(header['user_id']),
      customerId: readStringOrNull(header['customer_id']),
      cashSessionId: readStringOrNull(header['cash_session_id']),
      status: readString(header['status'], field: 'status'),
      subtotalAmount: readMoney(header['subtotal_amount'], field: 'subtotal'),
      discountAmount: readMoney(header['discount_amount'], field: 'discount'),
      taxAmount: readMoney(header['tax_amount'], field: 'tax'),
      totalAmount: readMoney(header['total_amount'], field: 'total'),
      note: readStringOrNull(header['note']),
      items: itemRows
          .map(
            (Map<String, Object?> row) => SaleItem(
              id: readString(row['id'], field: 'id'),
              transactionId: id,
              productId: readString(row['product_id'], field: 'product_id'),
              nameSnapshot: readString(row['name_snapshot'], field: 'name'),
              qty: readInt(row['qty'], field: 'qty'),
              unitPrice: readMoney(row['unit_price'], field: 'unit_price'),
              costPrice: readMoney(row['cost_price'], field: 'cost_price'),
              discountAmount: readMoney(
                row['discount_amount'],
                field: 'item_discount',
              ),
              lineTotal: readMoney(row['line_total'], field: 'line_total'),
            ),
          )
          .toList(),
      payments: paymentRows
          .map(
            (Map<String, Object?> row) => SalePayment(
              id: readString(row['id'], field: 'id'),
              transactionId: id,
              method: readString(row['method'], field: 'method'),
              amount: readMoney(row['amount'], field: 'amount'),
              tenderedAmount: readMoney(
                row['tendered_amount'],
                field: 'tendered',
              ),
              changeAmount: readMoney(row['change_amount'], field: 'change'),
            ),
          )
          .toList(),
      createdAt: readInt(header['created_at'], field: 'created_at'),
      updatedAt: readInt(header['updated_at'], field: 'updated_at'),
    );
  }

  void _assertPayment(SalePaymentDraft payment) {
    if (payment.amount < 0 ||
        payment.tenderedAmount < 0 ||
        payment.changeAmount < 0) {
      throw const ValidationException('Nominal pembayaran harus integer >= 0');
    }
    final PaymentMethod method = PaymentMethod.parse(payment.method);
    if (method.isCash) {
      if (payment.tenderedAmount == 0) {
        if (payment.changeAmount != 0) {
          throw const ValidationException('Kembalian tidak sesuai');
        }
        return;
      }
      if (payment.tenderedAmount < payment.amount) {
        throw const ValidationException('Uang diterima kurang dari total');
      }
      if (payment.changeAmount != payment.tenderedAmount - payment.amount) {
        throw const ValidationException('Kembalian tidak sesuai');
      }
      return;
    }
    if (payment.changeAmount != 0) {
      throw const ValidationException('Metode ini tidak memiliki kembalian');
    }
  }
}
