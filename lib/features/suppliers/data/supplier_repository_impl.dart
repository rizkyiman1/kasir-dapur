import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/contacts/data/contact_history_store.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier_repository.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteSupplierRepository implements SupplierRepository {
  SqliteSupplierRepository({
    required AppDatabase database,
    required ClockService clock,
    Uuid? uuid,
  }) : _database = database,
       _clock = clock,
       _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<Supplier> create(NewSupplier input) async {
    final String name = input.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('Nama pemasok wajib diisi');
    }
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await (await _database.database).transaction((Transaction txn) async {
      await txn.insert(DatabaseConstants.tableSuppliers, <String, Object?>{
        'id': id,
        'business_id': input.businessId,
        'name': name,
        'phone': blankToNull(input.contact),
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
        partyType: ContactParty.supplier,
        partyId: id,
        event: ContactEvent.created,
        summary: 'Pemasok ditambahkan',
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: input.businessId,
        aggregate: SyncAggregate.supplier,
        entityId: id,
      );
    });
    return (await getById(id))!;
  }

  @override
  Future<Supplier> update(Supplier supplier) async {
    final String name = supplier.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('Nama pemasok wajib diisi');
    }
    final int now = _clock.nowEpochMs();
    await (await _database.database).transaction((Transaction txn) async {
      final int changed = await txn.update(
        DatabaseConstants.tableSuppliers,
        <String, Object?>{
          'name': name,
          'phone': blankToNull(supplier.contact),
          'address': blankToNull(supplier.address),
          'notes': blankToNull(supplier.notes),
          'updated_at': now,
        },
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object>[supplier.id],
      );
      if (changed == 0) {
        throw const NotFoundException('Pemasok tidak ditemukan');
      }
      await writeContactHistory(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: supplier.businessId,
        partyType: ContactParty.supplier,
        partyId: supplier.id,
        event: ContactEvent.updated,
        summary: 'Data pemasok diubah',
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: supplier.businessId,
        aggregate: SyncAggregate.supplier,
        entityId: supplier.id,
      );
    });
    return (await getById(supplier.id))!;
  }

  @override
  Future<Supplier?> getById(String id) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSuppliers,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _map(rows.first);
  }

  @override
  Future<List<Supplier>> search({
    required String businessId,
    String query = '',
  }) async {
    final String trimmed = query.trim();
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSuppliers,
      where: trimmed.isEmpty
          ? 'business_id = ? AND deleted_at IS NULL'
          : 'business_id = ? AND deleted_at IS NULL AND '
                '(name LIKE ? OR IFNULL(phone, \'\') LIKE ?)',
      whereArgs: trimmed.isEmpty
          ? <Object>[businessId]
          : <Object>[businessId, '%$trimmed%', '%$trimmed%'],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_map).toList();
  }

  @override
  Future<List<ContactHistoryEntry>> history(String supplierId) async {
    return listContactHistory(
      await _database.database,
      partyType: ContactParty.supplier,
      partyId: supplierId,
    );
  }

  @override
  Future<ContactHistoryEntry> addHistoryNote({
    required String supplierId,
    required String note,
  }) async {
    final String body = note.trim();
    if (body.isEmpty) {
      throw const ValidationException('Catatan riwayat wajib diisi');
    }
    final Supplier? supplier = await getById(supplierId);
    if (supplier == null) {
      throw const NotFoundException('Pemasok tidak ditemukan');
    }
    await writeContactHistory(
      await _database.database,
      clock: _clock,
      uuid: _uuid,
      businessId: supplier.businessId,
      partyType: ContactParty.supplier,
      partyId: supplierId,
      event: ContactEvent.note,
      summary: body,
    );
    final List<ContactHistoryEntry> rows = await history(supplierId);
    return rows.first;
  }

  @override
  Future<void> softDelete(String id) async {
    final Supplier? existing = await getById(id);
    if (existing == null) {
      throw const NotFoundException('Pemasok tidak ditemukan');
    }
    final int now = _clock.nowEpochMs();
    final int changed = await (await _database.database).transaction((
      Transaction txn,
    ) async {
      final int updated = await txn.update(
        DatabaseConstants.tableSuppliers,
        <String, Object>{'deleted_at': now, 'updated_at': now},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object>[id],
      );
      if (updated > 0) {
        await enqueueEntity(
          txn,
          clock: _clock,
          uuid: _uuid,
          businessId: existing.businessId,
          aggregate: SyncAggregate.supplier,
          entityId: id,
        );
      }
      return updated;
    });
    if (changed == 0) {
      throw const NotFoundException('Pemasok tidak ditemukan');
    }
  }

  Supplier _map(Map<String, Object?> row) {
    return Supplier(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      name: readString(row['name'], field: 'name'),
      contact: readStringOrNull(row['phone']),
      address: readStringOrNull(row['address']),
      notes: readStringOrNull(row['notes']),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
      deletedAt: readIntOrNull(row['deleted_at']),
    );
  }
}
