import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/products/domain/catalog_lookups.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:uuid/uuid.dart';

final class SqliteCategoryRepository implements CategoryRepository {
  SqliteCategoryRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<CatalogCategory> create({
    required String businessId,
    required String name,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Nama kategori wajib diisi');
    }
    await _assertUnique(businessId: businessId, name: trimmed);
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await _database.runInTransaction((txn) async {
      await txn.insert(DatabaseConstants.tableCategories, <String, Object?>{
        'id': id,
        'business_id': businessId,
        'name': trimmed,
        'created_at': now,
        'updated_at': now,
        'deleted_at': null,
      });
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        aggregate: SyncAggregate.category,
        entityId: id,
      );
    });
    return CatalogCategory(
      id: id,
      businessId: businessId,
      name: trimmed,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<CatalogCategory> rename({
    required String id,
    required String name,
  }) async {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Nama kategori wajib diisi');
    }
    final CatalogCategory? current = await _getById(id);
    if (current == null) {
      throw const NotFoundException('Kategori tidak ditemukan');
    }
    await _assertUnique(
      businessId: current.businessId,
      name: trimmed,
      excludeId: id,
    );
    final int now = _clock.nowEpochMs();
    await _database.runInTransaction((txn) async {
      await txn.update(
        DatabaseConstants.tableCategories,
        <String, Object>{'name': trimmed, 'updated_at': now},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: <Object>[id],
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: current.businessId,
        aggregate: SyncAggregate.category,
        entityId: id,
      );
    });
    return CatalogCategory(
      id: current.id,
      businessId: current.businessId,
      name: trimmed,
      createdAt: current.createdAt,
      updatedAt: now,
    );
  }

  @override
  Future<List<CatalogCategory>> list({required String businessId}) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableCategories,
      where: 'business_id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[businessId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (Map<String, Object?> row) => CatalogCategory(
            id: readString(row['id'], field: 'id'),
            businessId: readString(row['business_id'], field: 'business_id'),
            name: readString(row['name'], field: 'name'),
            createdAt: readInt(row['created_at'], field: 'created_at'),
            updatedAt: readInt(row['updated_at'], field: 'updated_at'),
            deletedAt: readIntOrNull(row['deleted_at']),
          ),
        )
        .toList();
  }

  @override
  Future<void> archive(String id) async {
    final int now = _clock.nowEpochMs();
    final CatalogCategory? current = await _getById(id);
    if (current == null) {
      throw const NotFoundException('Kategori tidak ditemukan');
    }
    final int changed = await (await _database.database).update(
      DatabaseConstants.tableCategories,
      <String, Object>{'deleted_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
    );
    if (changed == 0) {
      throw const NotFoundException('Kategori tidak ditemukan');
    }
    await _database.runInTransaction((txn) async {
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: current.businessId,
        aggregate: SyncAggregate.category,
        entityId: id,
      );
    });
  }

  Future<CatalogCategory?> _getById(String id) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableCategories,
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    final Map<String, Object?> row = rows.first;
    return CatalogCategory(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      name: readString(row['name'], field: 'name'),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }

  Future<void> _assertUnique({
    required String businessId,
    required String name,
    String? excludeId,
  }) async {
    final String where = excludeId == null
        ? 'business_id = ? AND name = ? AND deleted_at IS NULL'
        : 'business_id = ? AND name = ? AND deleted_at IS NULL AND id != ?';
    final List<Object> args = excludeId == null
        ? <Object>[businessId, name]
        : <Object>[businessId, name, excludeId];
    final rows = await (await _database.database).query(
      DatabaseConstants.tableCategories,
      columns: <String>['id'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw const ConflictException('Nama kategori sudah dipakai');
    }
  }
}
