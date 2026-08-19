import 'dart:convert';

import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash.dart';
import 'package:kasir_dapur/features/cash_management/domain/cash_repository.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteCashRepository implements CashRepository {
  SqliteCashRepository({
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
  Future<CashSession> openSession({
    required String businessId,
    required int openingAmount,
    String? userId,
  }) async {
    if (openingAmount < 0) {
      throw const ValidationException('Opening balance harus integer >= 0');
    }
    return _database.runInTransaction((Transaction txn) async {
      final openRows = await txn.query(
        DatabaseConstants.tableCashSessions,
        where: "business_id = ? AND status = 'open'",
        whereArgs: <Object>[businessId],
        limit: 1,
      );
      if (openRows.isNotEmpty) {
        throw const ConflictException('Masih ada sesi kasir yang terbuka');
      }
      final String id = _uuid.v4();
      final int now = _clock.nowEpochMs();
      await txn.insert(DatabaseConstants.tableCashSessions, <String, Object?>{
        'id': id,
        'business_id': businessId,
        'user_id': userId,
        'opening_amount': openingAmount,
        'status': CashSessionStatus.open,
        'opened_at': now,
        'created_at': now,
        'updated_at': now,
      });
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        aggregate: SyncAggregate.cashSession,
        entityId: id,
      );
      return (await _getById(txn, id))!;
    });
  }

  @override
  Future<CashMovement> addMovement({
    required String sessionId,
    required String type,
    required int amount,
    String? note,
  }) async {
    if (type != CashMovementType.cashIn && type != CashMovementType.cashOut) {
      throw const ValidationException('Tipe mutasi kas harus in atau out');
    }
    if (amount <= 0) {
      throw const ValidationException('Nominal mutasi kas harus integer > 0');
    }
    return _database.runInTransaction((Transaction txn) async {
      final CashSession? session = await _getById(txn, sessionId);
      if (session == null || !session.isOpen) {
        throw const ConflictException('Sesi kasir tidak terbuka');
      }
      final String id = _uuid.v4();
      final int now = _clock.nowEpochMs();
      await txn.insert(DatabaseConstants.tableCashMovements, <String, Object?>{
        'id': id,
        'business_id': session.businessId,
        'session_id': sessionId,
        'type': type,
        'amount': amount,
        'note': note,
        'created_at': now,
        'updated_at': now,
      });
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: session.businessId,
        aggregate: SyncAggregate.cashMovement,
        entityId: id,
      );
      return CashMovement(
        id: id,
        businessId: session.businessId,
        sessionId: sessionId,
        type: type,
        amount: amount,
        note: note,
        createdAt: now,
      );
    });
  }

  @override
  Future<CashSession> closeSession({
    required String sessionId,
    required int countedAmount,
  }) async {
    if (countedAmount < 0) {
      throw const ValidationException('Actual cash harus integer >= 0');
    }
    return _database.runInTransaction((Transaction txn) async {
      final CashSession? session = await _getById(txn, sessionId);
      if (session == null || !session.isOpen) {
        throw const ConflictException('Sesi kasir tidak terbuka');
      }
      final _DrawerTotals totals = await _totals(txn, session);
      final int now = _clock.nowEpochMs();
      final CashClosingReport report = CashClosingReport(
        openingAmount: session.openingAmount,
        cashSales: totals.cashSales,
        nonCashSales: totals.nonCashSales,
        cashIn: totals.cashIn,
        cashOut: totals.cashOut,
        expectedAmount: totals.expected,
        actualAmount: countedAmount,
        differenceAmount: countedAmount - totals.expected,
        transactionCount: totals.transactionCount,
        closedAt: now,
      );
      await txn.update(
        DatabaseConstants.tableCashSessions,
        <String, Object>{
          'closing_amount': countedAmount,
          'expected_amount': report.expectedAmount,
          'difference_amount': report.differenceAmount,
          'status': CashSessionStatus.closed,
          'closed_at': now,
          'updated_at': now,
          'report_json': jsonEncode(report.toJson()),
        },
        where: 'id = ?',
        whereArgs: <Object>[sessionId],
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: session.businessId,
        aggregate: SyncAggregate.cashSession,
        entityId: sessionId,
      );
      return (await _getById(txn, sessionId))!;
    });
  }

  @override
  Future<CashSession?> getOpenSession(String businessId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableCashSessions,
      where: "business_id = ? AND status = 'open'",
      whereArgs: <Object>[businessId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapSession(rows.first);
  }

  @override
  Future<CashSession?> getSession(String id) async {
    return _getById(await _database.database, id);
  }

  @override
  Future<CashDrawerSnapshot> drawer(String sessionId) async {
    final Database db = await _database.database;
    final CashSession? session = await _getById(db, sessionId);
    if (session == null) {
      throw const NotFoundException('Sesi kasir tidak ditemukan');
    }
    final _DrawerTotals totals = await _totals(db, session);
    return CashDrawerSnapshot(
      session: session,
      cashSales: totals.cashSales,
      nonCashSales: totals.nonCashSales,
      cashIn: totals.cashIn,
      cashOut: totals.cashOut,
      expectedAmount: totals.expected,
      transactionCount: totals.transactionCount,
      movements: await _movements(db, sessionId),
      sales: await _sales(db, sessionId),
    );
  }

  @override
  Future<List<CashSession>> listClosed({
    required String businessId,
    int limit = 20,
  }) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableCashSessions,
      where: "business_id = ? AND status = 'closed'",
      whereArgs: <Object>[businessId],
      orderBy: 'closed_at DESC',
      limit: limit,
    );
    return rows.map(_mapSession).toList();
  }

  Future<CashSession?> _getById(DatabaseExecutor executor, String id) async {
    final rows = await executor.query(
      DatabaseConstants.tableCashSessions,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapSession(rows.first);
  }

  Future<_DrawerTotals> _totals(
    DatabaseExecutor executor,
    CashSession session,
  ) async {
    final int cashSales = await _scalar(
      executor,
      '''
SELECT CAST(COALESCE(SUM(p.amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tablePayments} p
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = p.transaction_id
WHERE t.cash_session_id = ?
  AND t.status = 'completed'
  AND p.method = 'cash'
''',
      <Object>[session.id],
    );
    final int nonCashSales = await _scalar(
      executor,
      '''
SELECT CAST(COALESCE(SUM(p.amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tablePayments} p
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = p.transaction_id
WHERE t.cash_session_id = ?
  AND t.status = 'completed'
  AND p.method != 'cash'
''',
      <Object>[session.id],
    );
    final int cashIn = await _scalar(
      executor,
      '''
SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableCashMovements}
WHERE session_id = ? AND type = 'in'
''',
      <Object>[session.id],
    );
    final int cashOut = await _scalar(
      executor,
      '''
SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableCashMovements}
WHERE session_id = ? AND type = 'out'
''',
      <Object>[session.id],
    );
    final int transactionCount = await _scalar(
      executor,
      '''
SELECT CAST(COUNT(*) AS INTEGER) AS value
FROM ${DatabaseConstants.tableTransactions}
WHERE cash_session_id = ? AND status = 'completed'
''',
      <Object>[session.id],
    );
    return _DrawerTotals(
      cashSales: cashSales,
      nonCashSales: nonCashSales,
      cashIn: cashIn,
      cashOut: cashOut,
      transactionCount: transactionCount,
      expected: session.openingAmount + cashSales + cashIn - cashOut,
    );
  }

  Future<List<CashMovement>> _movements(
    DatabaseExecutor executor,
    String sessionId,
  ) async {
    final rows = await executor.query(
      DatabaseConstants.tableCashMovements,
      where: 'session_id = ?',
      whereArgs: <Object>[sessionId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (Map<String, Object?> row) => CashMovement(
            id: readString(row['id'], field: 'id'),
            businessId: readString(row['business_id'], field: 'business_id'),
            sessionId: readString(row['session_id'], field: 'session_id'),
            type: readString(row['type'], field: 'type'),
            amount: readMoney(row['amount'], field: 'amount'),
            note: readStringOrNull(row['note']),
            createdAt: readInt(row['created_at'], field: 'created_at'),
          ),
        )
        .toList();
  }

  Future<List<SessionSaleRow>> _sales(
    DatabaseExecutor executor,
    String sessionId,
  ) async {
    final rows = await executor.rawQuery(
      '''
SELECT t.id AS transaction_id,
       t.created_at AS created_at,
       t.total_amount AS total_amount,
       CAST(COALESCE(SUM(CASE WHEN p.method = 'cash' THEN p.amount ELSE 0 END), 0)
         AS INTEGER) AS cash_amount,
       CAST(COALESCE(SUM(CASE WHEN p.method != 'cash' THEN p.amount ELSE 0 END), 0)
         AS INTEGER) AS non_cash_amount
FROM ${DatabaseConstants.tableTransactions} t
LEFT JOIN ${DatabaseConstants.tablePayments} p ON p.transaction_id = t.id
WHERE t.cash_session_id = ? AND t.status = 'completed'
GROUP BY t.id
ORDER BY t.created_at DESC
''',
      <Object>[sessionId],
    );
    return rows
        .map(
          (Map<String, Object?> row) => SessionSaleRow(
            transactionId: readString(row['transaction_id'], field: 'id'),
            createdAt: _asInt(row['created_at']),
            totalAmount: _asInt(row['total_amount']),
            cashAmount: _asInt(row['cash_amount']),
            nonCashAmount: _asInt(row['non_cash_amount']),
          ),
        )
        .toList();
  }

  Future<int> _scalar(
    DatabaseExecutor executor,
    String sql,
    List<Object> args,
  ) async {
    final rows = await executor.rawQuery(sql, args);
    if (rows.isEmpty) {
      return 0;
    }
    return _asInt(rows.first.values.first);
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

  CashSession _mapSession(Map<String, Object?> row) {
    return CashSession(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      userId: readStringOrNull(row['user_id']),
      openingAmount: readMoney(row['opening_amount'], field: 'opening'),
      closingAmount: readIntOrNull(row['closing_amount']),
      expectedAmount: readIntOrNull(row['expected_amount']),
      differenceAmount: readIntOrNull(row['difference_amount']),
      status: readString(row['status'], field: 'status'),
      openedAt: readInt(row['opened_at'], field: 'opened_at'),
      closedAt: readIntOrNull(row['closed_at']),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
      closingReport: CashClosingReport.tryParse(
        readStringOrNull(row['report_json']),
      ),
    );
  }
}

final class _DrawerTotals {
  const _DrawerTotals({
    required this.cashSales,
    required this.nonCashSales,
    required this.cashIn,
    required this.cashOut,
    required this.transactionCount,
    required this.expected,
  });

  final int cashSales;
  final int nonCashSales;
  final int cashIn;
  final int cashOut;
  final int transactionCount;
  final int expected;
}
