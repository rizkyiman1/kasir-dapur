import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart.dart';
import 'package:kasir_dapur/features/cashier/domain/pos_cart_repository.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqlitePosCartRepository implements PosCartRepository {
  SqlitePosCartRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<PosCart> loadOrCreateOpen({
    required String businessId,
    String? userId,
  }) async {
    final Database db = await _database.database;
    final rows = await db.query(
      DatabaseConstants.tablePosCarts,
      where: 'business_id = ? AND status = ?',
      whereArgs: <Object>[businessId, PosCartStatus.open.storageValue],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return _map(rows.first);
    }
    return _insertOpen(businessId: businessId, userId: userId);
  }

  @override
  Future<PosCart> save(PosCart cart) async {
    final int now = _clock.nowEpochMs();
    final PosCart next = cart.copyWith(updatedAt: now);
    final int changed = await (await _database.database).update(
      DatabaseConstants.tablePosCarts,
      _row(next),
      where: 'id = ?',
      whereArgs: <Object>[cart.id],
    );
    if (changed == 0) {
      throw const NotFoundException('Keranjang tidak ditemukan');
    }
    return next;
  }

  @override
  Future<PosCart> hold(PosCart cart) async {
    if (cart.isEmpty) {
      throw const ValidationException('Keranjang kosong tidak dapat ditahan');
    }
    return _database.runInTransaction((Transaction txn) async {
      final int now = _clock.nowEpochMs();
      final PosCart held = cart.copyWith(
        status: PosCartStatus.held,
        updatedAt: now,
      );
      await txn.update(
        DatabaseConstants.tablePosCarts,
        _row(held),
        where: 'id = ? AND status = ?',
        whereArgs: <Object>[cart.id, PosCartStatus.open.storageValue],
      );
      await _insertOpenOn(
        txn,
        businessId: cart.businessId,
        userId: cart.userId,
      );
      return held;
    });
  }

  @override
  Future<List<PosCart>> listHeld({required String businessId}) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tablePosCarts,
      where: 'business_id = ? AND status = ?',
      whereArgs: <Object>[businessId, PosCartStatus.held.storageValue],
      orderBy: 'updated_at DESC',
    );
    return rows.map(_map).toList();
  }

  @override
  Future<PosCart> resume({
    required String id,
    required String businessId,
    String? userId,
  }) {
    return _database.runInTransaction((Transaction txn) async {
      final heldRows = await txn.query(
        DatabaseConstants.tablePosCarts,
        where: 'id = ? AND business_id = ? AND status = ?',
        whereArgs: <Object>[id, businessId, PosCartStatus.held.storageValue],
        limit: 1,
      );
      if (heldRows.isEmpty) {
        throw const NotFoundException('Transaksi tertahan tidak ditemukan');
      }
      final openRows = await txn.query(
        DatabaseConstants.tablePosCarts,
        where: 'business_id = ? AND status = ?',
        whereArgs: <Object>[businessId, PosCartStatus.open.storageValue],
        limit: 1,
      );
      if (openRows.isNotEmpty) {
        final PosCart open = _map(openRows.first);
        if (!open.isEmpty) {
          final int now = _clock.nowEpochMs();
          await txn.update(
            DatabaseConstants.tablePosCarts,
            _row(open.copyWith(status: PosCartStatus.held, updatedAt: now)),
            where: 'id = ?',
            whereArgs: <Object>[open.id],
          );
        } else {
          await txn.delete(
            DatabaseConstants.tablePosCarts,
            where: 'id = ?',
            whereArgs: <Object>[open.id],
          );
        }
      }
      final int now = _clock.nowEpochMs();
      await txn.update(
        DatabaseConstants.tablePosCarts,
        <String, Object>{
          'status': PosCartStatus.open.storageValue,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: <Object>[id],
      );
      final rows = await txn.query(
        DatabaseConstants.tablePosCarts,
        where: 'id = ?',
        whereArgs: <Object>[id],
        limit: 1,
      );
      return _map(rows.first);
    });
  }

  @override
  Future<PosCart> cancel(PosCart cart) async {
    await delete(cart.id);
    if (cart.status == PosCartStatus.open) {
      return _insertOpen(businessId: cart.businessId, userId: cart.userId);
    }
    return loadOrCreateOpen(businessId: cart.businessId, userId: cart.userId);
  }

  @override
  Future<void> delete(String id) async {
    await (await _database.database).delete(
      DatabaseConstants.tablePosCarts,
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  @override
  Future<PosCart?> getById(String id) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tablePosCarts,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _map(rows.first);
  }

  Future<PosCart> _insertOpen({
    required String businessId,
    String? userId,
  }) async {
    final Database db = await _database.database;
    return _insertOpenOn(db, businessId: businessId, userId: userId);
  }

  Future<PosCart> _insertOpenOn(
    DatabaseExecutor executor, {
    required String businessId,
    String? userId,
  }) async {
    final int now = _clock.nowEpochMs();
    final PosCart cart = PosCart(
      id: _uuid.v4(),
      businessId: businessId,
      userId: userId,
      clientUuid: _uuid.v4(),
      status: PosCartStatus.open,
      lines: const [],
      discountAmount: 0,
      createdAt: now,
      updatedAt: now,
    );
    await executor.insert(DatabaseConstants.tablePosCarts, _row(cart));
    return cart;
  }

  Map<String, Object?> _row(PosCart cart) {
    return <String, Object?>{
      'id': cart.id,
      'business_id': cart.businessId,
      'user_id': cart.userId,
      'client_uuid': cart.clientUuid,
      'status': cart.status.storageValue,
      'customer_id': cart.customerId,
      'customer_name': cart.customerName,
      'discount_amount': cart.discountAmount,
      'note': cart.note,
      'payload': cart.encodePayload(),
      'created_at': cart.createdAt,
      'updated_at': cart.updatedAt,
    };
  }

  PosCart _map(Map<String, Object?> row) {
    return PosCart(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      userId: readStringOrNull(row['user_id']),
      clientUuid: readString(row['client_uuid'], field: 'client_uuid'),
      status: PosCartStatus.parse(readString(row['status'], field: 'status')),
      customerId: readStringOrNull(row['customer_id']),
      customerName: readStringOrNull(row['customer_name']),
      discountAmount: readInt(row['discount_amount'], field: 'discount_amount'),
      note: readStringOrNull(row['note']),
      lines: PosCart.decodePayload(
        readString(row['payload'], field: 'payload'),
      ),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }
}
