import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_repository.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:sqflite/sqflite.dart';

final class SqliteDashboardRepository implements DashboardRepository {
  SqliteDashboardRepository({required this._database});

  final AppDatabase _database;

  static const int _recentLimit = 8;
  static const int _lowStockLimit = 10;

  @override
  Future<DashboardSnapshot> load({required DashboardDateRange range}) async {
    final Database db = await _database.database;
    final String? businessId = await _activeBusinessId(db);
    if (businessId == null) {
      return const DashboardSnapshot.empty();
    }

    final List<Object> periodArgs = <Object>[
      businessId,
      range.startMs,
      range.endMsExclusive,
    ];

    final int omzet = await _scalarInt(db, '''
SELECT COALESCE(SUM(total_amount), 0) AS value
FROM ${DatabaseConstants.tableTransactions}
WHERE business_id = ?
  AND status = 'completed'
  AND created_at >= ?
  AND created_at < ?
''', periodArgs);
    final int transactionCount = await _scalarInt(db, '''
SELECT COUNT(*) AS value
FROM ${DatabaseConstants.tableTransactions}
WHERE business_id = ?
  AND status = 'completed'
  AND created_at >= ?
  AND created_at < ?
''', periodArgs);
    final int grossProfit = await _scalarInt(db, '''
SELECT COALESCE(SUM(ti.line_total - (ti.cost_price * ti.qty)), 0) AS value
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
WHERE t.business_id = ?
  AND t.status = 'completed'
  AND t.created_at >= ?
  AND t.created_at < ?
''', periodArgs);
    final int productsSoldQty = await _scalarInt(db, '''
SELECT COALESCE(SUM(ti.qty), 0) AS value
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
WHERE t.business_id = ?
  AND t.status = 'completed'
  AND t.created_at >= ?
  AND t.created_at < ?
''', periodArgs);
    final int expensesTotal = await _scalarInt(db, '''
SELECT COALESCE(SUM(amount), 0) AS value
FROM ${DatabaseConstants.tableExpenses}
WHERE business_id = ?
  AND deleted_at IS NULL
  AND spent_at >= ?
  AND spent_at < ?
''', periodArgs);

    final ({int balance, bool open}) cash = await _cashBalance(db, businessId);
    final List<LowStockItem> lowStock = await _lowStock(db, businessId);
    final List<DashboardSaleSummary> recent = await _recentSales(
      db,
      periodArgs,
    );

    return DashboardSnapshot(
      businessId: businessId,
      omzet: omzet,
      transactionCount: transactionCount,
      grossProfit: grossProfit,
      productsSoldQty: productsSoldQty,
      expensesTotal: expensesTotal,
      cashBalance: cash.balance,
      hasOpenCashSession: cash.open,
      lowStock: lowStock,
      recentSales: recent,
    );
  }

  Future<String?> _activeBusinessId(Database db) async {
    final rows = await db.query(
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

  Future<({int balance, bool open})> _cashBalance(
    Database db,
    String businessId,
  ) async {
    final openRows = await db.query(
      DatabaseConstants.tableCashSessions,
      where: "business_id = ? AND status = 'open'",
      whereArgs: <Object>[businessId],
      limit: 1,
    );
    if (openRows.isNotEmpty) {
      final Map<String, Object?> session = openRows.first;
      final String sessionId = session['id']! as String;
      final int opening = _asInt(session['opening_amount']);
      final int movementNet = await _scalarInt(
        db,
        '''
SELECT COALESCE(SUM(CASE WHEN type = 'in' THEN amount ELSE -amount END), 0)
  AS value
FROM ${DatabaseConstants.tableCashMovements}
WHERE session_id = ?
''',
        <Object>[sessionId],
      );
      final int cashSales = await _scalarInt(
        db,
        '''
SELECT COALESCE(SUM(p.amount), 0) AS value
FROM ${DatabaseConstants.tablePayments} p
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = p.transaction_id
WHERE t.cash_session_id = ?
  AND t.status = 'completed'
  AND p.method = 'cash'
''',
        <Object>[sessionId],
      );
      return (balance: opening + movementNet + cashSales, open: true);
    }

    final closedRows = await db.query(
      DatabaseConstants.tableCashSessions,
      columns: <String>['closing_amount'],
      where: "business_id = ? AND status = 'closed'",
      whereArgs: <Object>[businessId],
      orderBy: 'closed_at DESC',
      limit: 1,
    );
    if (closedRows.isEmpty) {
      return (balance: 0, open: false);
    }
    return (balance: _asInt(closedRows.first['closing_amount']), open: false);
  }

  Future<List<LowStockItem>> _lowStock(Database db, String businessId) async {
    final rows = await db.rawQuery(
      '''
SELECT p.id AS product_id, p.name AS name, s.qty AS qty, p.min_stock AS min_stock
FROM ${DatabaseConstants.tableStock} s
INNER JOIN ${DatabaseConstants.tableProducts} p ON p.id = s.product_id
WHERE s.business_id = ?
  AND p.deleted_at IS NULL
  AND p.is_active = 1
  AND p.min_stock > 0
  AND s.qty <= p.min_stock
ORDER BY s.qty ASC, p.name ASC
LIMIT $_lowStockLimit
''',
      <Object>[businessId],
    );
    return rows
        .map(
          (Map<String, Object?> row) => LowStockItem(
            productId: row['product_id']! as String,
            name: row['name']! as String,
            qty: _asInt(row['qty']),
            minStock: _asInt(row['min_stock']),
          ),
        )
        .toList();
  }

  Future<List<DashboardSaleSummary>> _recentSales(
    Database db,
    List<Object> periodArgs,
  ) async {
    final rows = await db.rawQuery('''
SELECT id, total_amount, created_at
FROM ${DatabaseConstants.tableTransactions}
WHERE business_id = ?
  AND status = 'completed'
  AND created_at >= ?
  AND created_at < ?
ORDER BY created_at DESC
LIMIT $_recentLimit
''', periodArgs);
    return rows
        .map(
          (Map<String, Object?> row) => DashboardSaleSummary(
            id: row['id']! as String,
            totalAmount: _asInt(row['total_amount']),
            createdAt: _asInt(row['created_at']),
          ),
        )
        .toList();
  }

  Future<int> _scalarInt(Database db, String sql, List<Object> args) async {
    final rows = await db.rawQuery(sql, args);
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
      return value.toInt();
    }
    return 0;
  }
}
