import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/auth/domain/session.dart';
import 'package:kasir_dapur/features/auth/domain/session_repository.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:uuid/uuid.dart';

final class SqliteSessionRepository implements SessionRepository {
  SqliteSessionRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  @override
  Future<AuthSession?> current() async {
    final db = await _database.database;
    final rows = await db.query(
      DatabaseConstants.tableLocalSessions,
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _map(rows.first);
  }

  @override
  Future<AuthSession> start({required String userId}) async {
    final db = await _database.database;
    final int now = _clock.nowEpochMs();
    final AuthSession session = AuthSession(
      id: _uuid.v4(),
      userId: userId,
      startedAt: now,
      lastActiveAt: now,
      locked: false,
    );
    await db.transaction((txn) async {
      await txn.delete(DatabaseConstants.tableLocalSessions);
      await txn.insert(
        DatabaseConstants.tableLocalSessions,
        _toRow(session, createdAt: now, updatedAt: now),
      );
    });
    return session;
  }

  @override
  Future<AuthSession> touch(String id) async {
    final db = await _database.database;
    final int now = _clock.nowEpochMs();
    await db.update(
      DatabaseConstants.tableLocalSessions,
      <String, Object>{'last_active_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
    final AuthSession? session = await current();
    return session ??
        AuthSession(
          id: id,
          userId: '',
          startedAt: now,
          lastActiveAt: now,
          locked: false,
        );
  }

  @override
  Future<AuthSession> setLocked({
    required String id,
    required bool locked,
  }) async {
    final db = await _database.database;
    final int now = _clock.nowEpochMs();
    final Map<String, Object> values = <String, Object>{
      'locked': locked ? 1 : 0,
      'updated_at': now,
    };
    if (!locked) {
      values['last_active_at'] = now;
    }
    await db.update(
      DatabaseConstants.tableLocalSessions,
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
    final AuthSession? session = await current();
    return session ??
        AuthSession(
          id: id,
          userId: '',
          startedAt: now,
          lastActiveAt: now,
          locked: locked,
        );
  }

  @override
  Future<void> clear() async {
    final db = await _database.database;
    await db.delete(DatabaseConstants.tableLocalSessions);
  }

  Map<String, Object> _toRow(
    AuthSession session, {
    required int createdAt,
    required int updatedAt,
  }) {
    return <String, Object>{
      'id': session.id,
      'user_id': session.userId,
      'started_at': session.startedAt,
      'last_active_at': session.lastActiveAt,
      'locked': session.locked ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  AuthSession _map(Map<String, Object?> row) {
    return AuthSession(
      id: row['id']! as String,
      userId: row['user_id']! as String,
      startedAt: row['started_at']! as int,
      lastActiveAt: row['last_active_at']! as int,
      locked: (row['locked']! as int) != 0,
    );
  }
}
