import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/contacts/data/contact_history_store.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/customers/domain/customer_repository.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteCustomerRepository implements CustomerRepository {
  SqliteCustomerRepository({
    required AppDatabase database,
    required ClockService clock,
    Uuid? uuid,
  }) : _database = database,
       _clock = clock,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  static const String _selectWithTotals =
      '''
SELECT c.*,
  CAST(COALESCE(agg.cnt, 0) AS INTEGER) AS transaction_count,
  CAST(COALESCE(agg.spend, 0) AS INTEGER) AS spend_total
FROM ${DatabaseConstants.tableCustomers} c
LEFT JOIN (
  SELECT customer_id AS cid,
         COUNT(*) AS cnt,
         SUM(total_amount) AS spend
  FROM ${DatabaseConstants.tableTransactions}
  WHERE status = 'completed'
  GROUP BY customer_id
) agg ON agg.cid = c.id
''';

  @override
  Future<Customer> create(NewCustomer input) async {
    final String name = input.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('Nama pelanggan wajib diisi');
    }
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await (await _database.database).transaction((Transaction txn) async {
      await txn.insert(DatabaseConstants.tableCustomers, <String, Object?>{
        'id': id,
        'business_id': input.businessId,
        'name': name,
        'phone': blankToNull(input.phone),
        'email': blankToNull(input.email),
        'address': blankToNull(input.address),
        'notes': blankToNull(input.notes),
        'created_at': now,
        'updated_at': now,
      });
      await writeContactHistory(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: input.businessId,
        partyType: ContactParty.customer,
        partyId: id,
        event: ContactEvent.created,
        summary: 'Pelanggan ditambahkan',
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: input.businessId,
        aggregate: SyncAggregate.customer,
        entityId: id,
      );
    });
    return (await getById(id))!;
  }

  @override
  Future<Customer> update(Customer customer) async {
    final String name = customer.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('Nama pelanggan wajib diisi');
    }
    final int now = _clock.nowEpochMs();
    await (await _database.database).transaction((Transaction txn) async {
      final int changed = await txn.update(
        DatabaseConstants.tableCustomers,
        <String, Object?>{
          'name': name,
          'phone': blankToNull(customer.phone),
          'email': blankToNull(customer.email),
          'address': blankToNull(customer.address),
          'notes': blankToNull(customer.notes),
          'updated_at': now,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object>[customer.id],
      );
      if (changed == 0) {
        throw const NotFoundException('Pelanggan tidak ditemukan');
      }
      await writeContactHistory(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: customer.businessId,
        partyType: ContactParty.customer,
        partyId: customer.id,
        event: ContactEvent.updated,
        summary: 'Data pelanggan diubah',
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: customer.businessId,
        aggregate: SyncAggregate.customer,
        entityId: customer.id,
      );
    });
    return (await getById(customer.id))!;
  }

  @override
  Future<Customer?> getById(String id) async {
    final rows = await (await _database.database).rawQuery(
      '$_selectWithTotals WHERE c.id = ? AND c.deleted_at IS NULL LIMIT 1',
      <Object>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _map(rows.first);
  }

  @override
  Future<List<Customer>> search({
    required String businessId,
    String query = '',
  }) async {
    final String trimmed = query.trim();
    final String where = trimmed.isEmpty
        ? 'c.business_id = ? AND c.deleted_at IS NULL'
        : 'c.business_id = ? AND c.deleted_at IS NULL AND '
              '(c.name LIKE ? OR IFNULL(c.phone, \'\') LIKE ?)';
    final List<Object> args = trimmed.isEmpty
        ? <Object>[businessId]
        : <Object>[businessId, '%$trimmed%', '%$trimmed%'];
    final rows = await (await _database.database).rawQuery(
      '$_selectWithTotals WHERE $where ORDER BY c.name COLLATE NOCASE ASC',
      args,
    );
    return rows.map(_map).toList();
  }

  @override
  Future<List<CustomerSaleHistory>> salesHistory(String customerId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableTransactions,
      where: "customer_id = ? AND status = 'completed'",
      whereArgs: <Object>[customerId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (Map<String, Object?> row) => CustomerSaleHistory(
            transactionId: readString(row['id'], field: 'id'),
            status: readString(row['status'], field: 'status'),
            totalAmount: readMoney(row['total_amount'], field: 'total_amount'),
            createdAt: readInt(row['created_at'], field: 'created_at'),
            note: readStringOrNull(row['note']),
          ),
        )
        .toList();
  }

  @override
  Future<List<ContactHistoryEntry>> profileHistory(String customerId) async {
    return listContactHistory(
      await _database.database,
      partyType: ContactParty.customer,
      partyId: customerId,
    );
  }

  @override
  Future<void> softDelete(String id) async {
    final int now = _clock.nowEpochMs();
    final int changed = await (await _database.database).update(
      DatabaseConstants.tableCustomers,
      <String, Object>{'deleted_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
    );
    if (changed == 0) {
      throw const NotFoundException('Pelanggan tidak ditemukan');
    }
  }

  Customer _map(Map<String, Object?> row) {
    return Customer(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      name: readString(row['name'], field: 'name'),
      phone: readStringOrNull(row['phone']),
      email: readStringOrNull(row['email']),
      address: readStringOrNull(row['address']),
      notes: readStringOrNull(row['notes']),
      transactionCount: _asInt(row['transaction_count']),
      spendTotal: _asInt(row['spend_total']),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
      deletedAt: readIntOrNull(row['deleted_at']),
    );
  }

  int _asInt(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse('$value') ?? 0;
  }
}
