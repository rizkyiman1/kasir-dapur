import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/products/domain/catalog_lookups.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:uuid/uuid.dart';

final class SqliteBusinessRepository implements BusinessRepository {
  SqliteBusinessRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<String?> activeId() async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableBusinesses,
      columns: <String>['id'],
      where: "status = 'active' AND deleted_at IS NULL",
      orderBy: 'created_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['id'] as String?;
  }

  @override
  Future<String> ensureActive() async {
    final String? existing = await activeId();
    if (existing != null) {
      return existing;
    }
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await _database.runInTransaction((txn) async {
      await txn.insert(DatabaseConstants.tableBusinesses, <String, Object>{
        'id': id,
        'name': AppConstants.defaultBusinessDisplayName,
        'legal_name': Brand.companyName,
        'status': 'active',
        'created_at': now,
        'updated_at': now,
      });
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: id,
        aggregate: SyncAggregate.business,
        entityId: id,
      );
    });
    return id;
  }
}
