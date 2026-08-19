import 'dart:convert';

import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/features/sync/domain/sync_repository.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<SyncJob> enqueueSync(
  DatabaseExecutor executor, {
  required ClockService clock,
  required Uuid uuid,
  required String businessId,
  required String clientUuid,
  required String aggregate,
  required String operation,
  required String payload,
}) async {
  final existing = await executor.query(
    DatabaseConstants.tableSyncQueue,
    where: 'business_id = ? AND client_uuid = ?',
    whereArgs: <Object>[businessId, clientUuid],
    limit: 1,
  );
  final int now = clock.nowEpochMs();
  if (existing.isNotEmpty) {
    final SyncJob current = _mapJob(existing.first);
    if (current.status == SyncJobStatus.pending ||
        current.status == SyncJobStatus.syncing) {
      return current;
    }
    await executor.update(
      DatabaseConstants.tableSyncQueue,
      <String, Object>{
        'status': SyncJobStatus.pending,
        'payload': payload,
        'operation': operation,
        'last_error': '',
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: <Object>[current.id],
    );
    return _mapJob(<String, Object?>{
      ...existing.first,
      'status': SyncJobStatus.pending,
      'payload': payload,
      'operation': operation,
      'updated_at': now,
    });
  }
  final String id = uuid.v4();
  final Map<String, Object> row = <String, Object>{
    'id': id,
    'business_id': businessId,
    'client_uuid': clientUuid,
    'aggregate': aggregate,
    'operation': operation,
    'payload': payload,
    'status': SyncJobStatus.pending,
    'attempts': 0,
    'created_at': now,
    'updated_at': now,
  };
  await executor.insert(DatabaseConstants.tableSyncQueue, row);
  return _mapJob(row);
}

Future<SyncJob> enqueueEntity(
  DatabaseExecutor executor, {
  required ClockService clock,
  required Uuid uuid,
  required String businessId,
  required SyncAggregate aggregate,
  required String entityId,
  String operation = 'upsert',
}) {
  return enqueueSync(
    executor,
    clock: clock,
    uuid: uuid,
    businessId: businessId,
    clientUuid: '${aggregate.storageValue}:$entityId',
    aggregate: aggregate.storageValue,
    operation: operation,
    payload: jsonEncode(<String, String>{'id': entityId}),
  );
}

SyncJob _mapJob(Map<String, Object?> row) {
  return SyncJob(
    id: readString(row['id'], field: 'id'),
    businessId: readString(row['business_id'], field: 'business_id'),
    clientUuid: readString(row['client_uuid'], field: 'client_uuid'),
    aggregate: readString(row['aggregate'], field: 'aggregate'),
    operation: readString(row['operation'], field: 'operation'),
    payload: readString(row['payload'], field: 'payload'),
    status: readString(row['status'], field: 'status'),
    attempts: readInt(row['attempts'], field: 'attempts'),
    lastError: readStringOrNull(row['last_error']),
    createdAt: readInt(row['created_at'], field: 'created_at'),
    updatedAt: readInt(row['updated_at'], field: 'updated_at'),
  );
}

final class SqliteSyncRepository implements SyncRepository {
  SqliteSyncRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<SyncJob> enqueue({
    required String businessId,
    required String clientUuid,
    required String aggregate,
    required String operation,
    required String payload,
  }) {
    return _database.runInTransaction((Transaction txn) {
      return enqueueSync(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        clientUuid: clientUuid,
        aggregate: aggregate,
        operation: operation,
        payload: payload,
      );
    });
  }

  @override
  Future<List<SyncJob>> pending({required String businessId}) {
    return _list(businessId, SyncJobStatus.pending);
  }

  @override
  Future<List<SyncJob>> failed({required String businessId}) {
    return _list(businessId, SyncJobStatus.failed);
  }

  Future<List<SyncJob>> _list(String businessId, String status) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSyncQueue,
      where: 'business_id = ? AND status = ?',
      whereArgs: <Object>[businessId, status],
      orderBy: 'created_at ASC',
    );
    return rows.map(_mapJob).toList();
  }

  @override
  Future<int> countByStatus({
    required String businessId,
    required String status,
  }) async {
    final rows = await (await _database.database).rawQuery(
      '''
SELECT CAST(COUNT(*) AS INTEGER) AS value
FROM ${DatabaseConstants.tableSyncQueue}
WHERE business_id = ? AND status = ?
''',
      <Object>[businessId, status],
    );
    return readInt(rows.first['value'], field: 'value');
  }

  @override
  Future<void> markSyncing(String id) async {
    await (await _database.database).update(
      DatabaseConstants.tableSyncQueue,
      <String, Object>{
        'status': SyncJobStatus.syncing,
        'updated_at': _clock.nowEpochMs(),
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  @override
  Future<void> markDone(String id) async {
    await (await _database.database).update(
      DatabaseConstants.tableSyncQueue,
      <String, Object>{
        'status': SyncJobStatus.done,
        'updated_at': _clock.nowEpochMs(),
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  @override
  Future<void> markFailed({required String id, required String error}) async {
    final Database db = await _database.database;
    final rows = await db.query(
      DatabaseConstants.tableSyncQueue,
      columns: <String>['attempts'],
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    final int attempts = rows.isEmpty
        ? 0
        : readInt(rows.first['attempts'], field: 'attempts');
    await db.update(
      DatabaseConstants.tableSyncQueue,
      <String, Object>{
        'status': SyncJobStatus.failed,
        'last_error': error,
        'attempts': attempts + 1,
        'updated_at': _clock.nowEpochMs(),
      },
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  @override
  Future<int> retryFailed(String businessId) async {
    return (await _database.database).update(
      DatabaseConstants.tableSyncQueue,
      <String, Object>{
        'status': SyncJobStatus.pending,
        'attempts': 0,
        'updated_at': _clock.nowEpochMs(),
      },
      where: 'business_id = ? AND status = ?',
      whereArgs: <Object>[businessId, SyncJobStatus.failed],
    );
  }

  @override
  Future<void> markPendingForRetry(String id) async {
    await (await _database.database).update(
      DatabaseConstants.tableSyncQueue,
      <String, Object>{
        'status': SyncJobStatus.pending,
        'updated_at': _clock.nowEpochMs(),
      },
      where: 'id = ? AND status = ?',
      whereArgs: <Object>[id, SyncJobStatus.failed],
    );
  }

  @override
  Future<void> requeueStaleSyncing(String businessId) async {
    await (await _database.database).update(
      DatabaseConstants.tableSyncQueue,
      <String, Object>{
        'status': SyncJobStatus.pending,
        'updated_at': _clock.nowEpochMs(),
      },
      where: 'business_id = ? AND status = ?',
      whereArgs: <Object>[businessId, SyncJobStatus.syncing],
    );
  }

  @override
  Future<List<SyncLog>> recentLogs({
    required String businessId,
    int limit = 20,
  }) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSyncLogs,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows
        .map(
          (Map<String, Object?> row) => SyncLog(
            id: readString(row['id'], field: 'id'),
            businessId: readString(row['business_id'], field: 'business_id'),
            queueId: readStringOrNull(row['queue_id']),
            direction: readString(row['direction'], field: 'direction'),
            status: readString(row['status'], field: 'status'),
            message: readStringOrNull(row['message']),
            createdAt: readInt(row['created_at'], field: 'created_at'),
          ),
        )
        .toList();
  }

  @override
  Future<SyncLog> writeLog({
    required String businessId,
    String? queueId,
    required String direction,
    required String status,
    String? message,
  }) async {
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await (await _database.database).insert(
      DatabaseConstants.tableSyncLogs,
      <String, Object?>{
        'id': id,
        'business_id': businessId,
        'queue_id': queueId,
        'direction': direction,
        'status': status,
        'message': message,
        'created_at': now,
        'updated_at': now,
      },
    );
    return SyncLog(
      id: id,
      businessId: businessId,
      queueId: queueId,
      direction: direction,
      status: status,
      message: message,
      createdAt: now,
    );
  }
}
