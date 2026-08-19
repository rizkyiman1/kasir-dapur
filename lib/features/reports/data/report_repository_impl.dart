import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/features/reports/domain/report_filter.dart';
import 'package:kasir_dapur/features/reports/domain/report_repository.dart';
import 'package:kasir_dapur/features/reports/domain/report_snapshot.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';
import 'package:sqflite/sqflite.dart';

/// Laporan dari agregasi INTEGER SQLite. Tidak menjumlahkan uang di Dart
/// dari daftar transaksi, dan tidak memakai tipe floating point.
final class SqliteReportRepository implements ReportRepository {
  SqliteReportRepository({required this._database});

  final AppDatabase _database;

  // Limit baris per laporan. Cukup untuk UMKM dengan ratusan transaksi/hari.
  // Jika di masa depan perlu lebih, tambahkan parameter offset ke ReportQuery.
  static const int _salesLimit = 500;
  static const int _topProductsLimit = 50;
  static const int _stockLimit = 2000;
  static const int _expensesLimit = 500;

  static const String _cashierNameSql =
      "COALESCE(lu.display_name, u.display_name, 'Tanpa kasir')";

  @override
  Future<ReportSnapshot> load(ReportQuery query) async {
    final Database db = await _database.database;
    final String? businessId = await _activeBusinessId(db);
    if (businessId == null) {
      return const ReportSnapshot.empty();
    }

    final _SqlParts sales = _SqlParts.sales(
      businessId: businessId,
      query: query,
    );
    final _SqlParts items = _SqlParts.items(
      businessId: businessId,
      query: query,
    );

    final int transactionCount = await _scalarInt(db, '''
SELECT CAST(COUNT(*) AS INTEGER) AS value
FROM ${DatabaseConstants.tableTransactions} t
WHERE ${sales.where}
''', sales.args);

    final int omzet = query.hasLineFilter
        ? await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(ti.line_total), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = ti.product_id
WHERE ${items.where}
''', items.args)
        : await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(t.total_amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableTransactions} t
WHERE ${sales.where}
''', sales.args);

    final int cogs = await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(ti.cost_price * ti.qty), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = ti.product_id
WHERE ${items.where}
''', items.args);

    final int productsSoldQty = await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(ti.qty), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = ti.product_id
WHERE ${items.where}
''', items.args);

    final int expensesTotal = await _scalarInt(
      db,
      '''
SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableExpenses}
WHERE business_id = ?
  AND deleted_at IS NULL
  AND spent_at >= ?
  AND spent_at < ?
''',
      <Object>[businessId, query.range.startMs, query.range.endMsExclusive],
    );

    final int grossProfit = omzet - cogs;
    final ReportCashSnapshot cash = await _cash(
      db,
      businessId: businessId,
      query: query,
      sales: sales,
    );

    return ReportSnapshot(
      businessId: businessId,
      omzet: omzet,
      transactionCount: transactionCount,
      productsSoldQty: productsSoldQty,
      cogs: cogs,
      grossProfit: grossProfit,
      expensesTotal: expensesTotal,
      sales: await _sales(db, query: query, sales: sales, items: items),
      topProducts: await _topProducts(db, items: items),
      stock: await _stock(db, businessId: businessId, query: query),
      lowStock: await _lowStock(db, businessId: businessId, query: query),
      expenses: await _expenses(db, businessId: businessId, query: query),
      cash: cash,
      paymentMethods: await _paymentMethods(db, query: query, sales: sales),
      salesByCashier: await _salesByCashier(
        db,
        query: query,
        sales: sales,
        items: items,
      ),
      salesByCategory: await _salesByCategory(db, items: items),
    );
  }

  @override
  Future<ReportFilterOptions> filterOptions() async {
    final Database db = await _database.database;
    final String? businessId = await _activeBusinessId(db);
    if (businessId == null) {
      return const ReportFilterOptions();
    }

    final productRows = await db.rawQuery(
      '''
SELECT id, name
FROM ${DatabaseConstants.tableProducts}
WHERE business_id = ? AND deleted_at IS NULL
ORDER BY name COLLATE NOCASE ASC
''',
      <Object>[businessId],
    );
    final categoryRows = await db.rawQuery(
      '''
SELECT id, name
FROM ${DatabaseConstants.tableCategories}
WHERE business_id = ? AND deleted_at IS NULL
ORDER BY name COLLATE NOCASE ASC
''',
      <Object>[businessId],
    );
    final cashierRows = await db.rawQuery(
      '''
SELECT id, name FROM (
  SELECT id, display_name AS name FROM ${DatabaseConstants.tableLocalUsers}
  UNION
  SELECT id, display_name AS name FROM ${DatabaseConstants.tableUsers}
  WHERE business_id = ? AND deleted_at IS NULL
) AS cashiers
ORDER BY name COLLATE NOCASE ASC
''',
      <Object>[businessId],
    );

    return ReportFilterOptions(
      products: productRows
          .map(
            (Map<String, Object?> row) => ReportFilterOption(
              id: row['id']! as String,
              label: row['name']! as String,
            ),
          )
          .toList(),
      categories: categoryRows
          .map(
            (Map<String, Object?> row) => ReportFilterOption(
              id: row['id']! as String,
              label: row['name']! as String,
            ),
          )
          .toList(),
      cashiers: [
        const ReportFilterOption(
          id: ReportFilter.noCashierId,
          label: 'Tanpa kasir',
        ),
        ...cashierRows.map(
          (Map<String, Object?> row) => ReportFilterOption(
            id: row['id']! as String,
            label: row['name']! as String,
          ),
        ),
      ],
    );
  }

  Future<List<ReportSaleRow>> _sales(
    Database db, {
    required ReportQuery query,
    required _SqlParts sales,
    required _SqlParts items,
  }) async {
    final String sql = query.hasLineFilter
        ? '''
SELECT t.id AS id,
       t.created_at AS created_at,
       $_cashierNameSql AS cashier_name,
       CAST(COALESCE(SUM(ti.line_total), 0) AS INTEGER) AS amount
FROM ${DatabaseConstants.tableTransactions} t
INNER JOIN ${DatabaseConstants.tableTransactionItems} ti
  ON ti.transaction_id = t.id
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = ti.product_id
LEFT JOIN ${DatabaseConstants.tableLocalUsers} lu ON lu.id = t.user_id
LEFT JOIN ${DatabaseConstants.tableUsers} u ON u.id = t.user_id
WHERE ${items.where}
GROUP BY t.id, t.created_at, $_cashierNameSql
ORDER BY t.created_at DESC
LIMIT $_salesLimit
'''
        : '''
SELECT t.id AS id,
       t.created_at AS created_at,
       $_cashierNameSql AS cashier_name,
       CAST(t.total_amount AS INTEGER) AS amount
FROM ${DatabaseConstants.tableTransactions} t
LEFT JOIN ${DatabaseConstants.tableLocalUsers} lu ON lu.id = t.user_id
LEFT JOIN ${DatabaseConstants.tableUsers} u ON u.id = t.user_id
WHERE ${sales.where}
ORDER BY t.created_at DESC
LIMIT $_salesLimit
''';
    final rows = await db.rawQuery(
      sql,
      query.hasLineFilter ? items.args : sales.args,
    );
    return rows
        .map(
          (Map<String, Object?> row) => ReportSaleRow(
            id: row['id']! as String,
            createdAt: _asInt(row['created_at'], field: 'created_at'),
            amount: _asInt(row['amount'], field: 'amount'),
            cashierName: row['cashier_name']! as String,
          ),
        )
        .toList();
  }

  Future<List<ReportNamedAmount>> _topProducts(
    Database db, {
    required _SqlParts items,
  }) async {
    final rows = await db.rawQuery('''
SELECT ti.product_id AS id,
       MAX(ti.name_snapshot) AS name,
       CAST(COALESCE(SUM(ti.qty), 0) AS INTEGER) AS qty,
       CAST(COALESCE(SUM(ti.line_total), 0) AS INTEGER) AS amount,
       CAST(COALESCE(SUM(ti.cost_price * ti.qty), 0) AS INTEGER) AS cogs,
       CAST(COALESCE(SUM(ti.line_total - (ti.cost_price * ti.qty)), 0) AS INTEGER)
         AS gross_profit
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = ti.product_id
WHERE ${items.where}
GROUP BY ti.product_id
ORDER BY qty DESC, amount DESC, name COLLATE NOCASE ASC
LIMIT $_topProductsLimit
''', items.args);
    return rows.map(_namedFromRow).toList();
  }

  Future<List<ReportStockRow>> _stock(
    Database db, {
    required String businessId,
    required ReportQuery query,
  }) async {
    return _stockRows(
      db,
      businessId: businessId,
      query: query,
      lowStockOnly: false,
    );
  }

  Future<List<ReportStockRow>> _lowStock(
    Database db, {
    required String businessId,
    required ReportQuery query,
  }) async {
    return _stockRows(
      db,
      businessId: businessId,
      query: query,
      lowStockOnly: true,
    );
  }

  Future<List<ReportStockRow>> _stockRows(
    Database db, {
    required String businessId,
    required ReportQuery query,
    required bool lowStockOnly,
  }) async {
    final List<String> clauses = <String>[
      's.business_id = ?',
      'p.deleted_at IS NULL',
    ];
    final List<Object> args = <Object>[businessId];
    if (query.productId != null) {
      clauses.add('p.id = ?');
      args.add(query.productId!);
    }
    if (query.categoryId != null) {
      clauses.add('p.category_id = ?');
      args.add(query.categoryId!);
    }
    if (lowStockOnly) {
      clauses.add('p.is_active = 1');
      clauses.add('p.min_stock > 0');
      clauses.add('s.qty <= p.min_stock');
    }
    final rows = await db.rawQuery('''
SELECT p.id AS product_id,
       p.name AS name,
       CAST(s.qty AS INTEGER) AS qty,
       CAST(p.min_stock AS INTEGER) AS min_stock,
       c.name AS category_name
FROM ${DatabaseConstants.tableStock} s
INNER JOIN ${DatabaseConstants.tableProducts} p ON p.id = s.product_id
LEFT JOIN ${DatabaseConstants.tableCategories} c ON c.id = p.category_id
WHERE ${clauses.join('\n  AND ')}
ORDER BY ${lowStockOnly ? 's.qty ASC, p.name COLLATE NOCASE ASC' : 'p.name COLLATE NOCASE ASC'}
LIMIT $_stockLimit
''', args);
    return rows
        .map(
          (Map<String, Object?> row) => ReportStockRow(
            productId: row['product_id']! as String,
            name: row['name']! as String,
            qty: _asInt(row['qty'], field: 'qty'),
            minStock: _asInt(row['min_stock'], field: 'min_stock'),
            categoryName: row['category_name'] as String?,
          ),
        )
        .toList();
  }

  Future<List<ReportExpenseRow>> _expenses(
    Database db, {
    required String businessId,
    required ReportQuery query,
  }) async {
    final rows = await db.rawQuery(
      '''
SELECT e.id AS id,
       CAST(e.amount AS INTEGER) AS amount,
       e.spent_at AS spent_at,
       e.note AS note,
       ec.name AS category_name
FROM ${DatabaseConstants.tableExpenses} e
LEFT JOIN ${DatabaseConstants.tableExpenseCategories} ec
  ON ec.id = e.category_id
WHERE e.business_id = ?
  AND e.deleted_at IS NULL
  AND e.spent_at >= ?
  AND e.spent_at < ?
ORDER BY e.spent_at DESC
LIMIT $_expensesLimit
''',
      <Object>[businessId, query.range.startMs, query.range.endMsExclusive],
    );
    return rows
        .map(
          (Map<String, Object?> row) => ReportExpenseRow(
            id: row['id']! as String,
            amount: _asInt(row['amount'], field: 'amount'),
            spentAt: _asInt(row['spent_at'], field: 'spent_at'),
            note: row['note'] as String?,
            categoryName: row['category_name'] as String?,
          ),
        )
        .toList();
  }

  Future<ReportCashSnapshot> _cash(
    Database db, {
    required String businessId,
    required ReportQuery query,
    required _SqlParts sales,
  }) async {
    final ({int balance, bool open}) current = await _currentCashBalance(
      db,
      businessId,
    );
    final int periodCashSales = await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(p.amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tablePayments} p
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = p.transaction_id
WHERE ${sales.where}
  AND p.method = 'cash'
''', sales.args);
    final int periodNonCashSales = await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(p.amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tablePayments} p
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = p.transaction_id
WHERE ${sales.where}
  AND p.method != 'cash'
''', sales.args);
    final List<Object> movementArgs = <Object>[
      businessId,
      query.range.startMs,
      query.range.endMsExclusive,
    ];
    final int periodCashIn = await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableCashMovements}
WHERE business_id = ?
  AND type = 'in'
  AND created_at >= ?
  AND created_at < ?
''', movementArgs);
    final int periodCashOut = await _scalarInt(db, '''
SELECT CAST(COALESCE(SUM(amount), 0) AS INTEGER) AS value
FROM ${DatabaseConstants.tableCashMovements}
WHERE business_id = ?
  AND type = 'out'
  AND created_at >= ?
  AND created_at < ?
''', movementArgs);
    return ReportCashSnapshot(
      currentBalance: current.balance,
      hasOpenSession: current.open,
      periodCashSales: periodCashSales,
      periodNonCashSales: periodNonCashSales,
      periodCashIn: periodCashIn,
      periodCashOut: periodCashOut,
    );
  }

  Future<({int balance, bool open})> _currentCashBalance(
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
      final int opening = _asInt(
        session['opening_amount'],
        field: 'opening_amount',
      );
      final int movementNet = await _scalarInt(
        db,
        '''
SELECT CAST(COALESCE(SUM(CASE WHEN type = 'in' THEN amount ELSE -amount END), 0)
  AS INTEGER) AS value
FROM ${DatabaseConstants.tableCashMovements}
WHERE session_id = ?
''',
        <Object>[sessionId],
      );
      final int cashSales = await _scalarInt(
        db,
        '''
SELECT CAST(COALESCE(SUM(p.amount), 0) AS INTEGER) AS value
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
    return (
      balance: _asInt(
        closedRows.first['closing_amount'],
        field: 'closing_amount',
      ),
      open: false,
    );
  }

  Future<List<ReportNamedAmount>> _paymentMethods(
    Database db, {
    required ReportQuery query,
    required _SqlParts sales,
  }) async {
    final List<String> extra = <String>[];
    final List<Object> args = List<Object>.from(sales.args);
    if (query.paymentMethod != null) {
      extra.add('p.method = ?');
      args.add(query.paymentMethod!);
    }
    final String methodWhere = extra.isEmpty
        ? sales.where
        : '${sales.where}\n  AND ${extra.join('\n  AND ')}';
    final rows = await db.rawQuery('''
SELECT p.method AS id,
       p.method AS name,
       CAST(COUNT(DISTINCT t.id) AS INTEGER) AS trx_count,
       CAST(COALESCE(SUM(p.amount), 0) AS INTEGER) AS amount
FROM ${DatabaseConstants.tablePayments} p
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = p.transaction_id
WHERE $methodWhere
GROUP BY p.method
ORDER BY amount DESC, p.method ASC
''', args);
    return rows
        .map(
          (Map<String, Object?> row) => ReportNamedAmount(
            id: row['id']! as String,
            name: _paymentLabel(row['name']! as String),
            amount: _asInt(row['amount'], field: 'amount'),
            count: _asInt(row['trx_count'], field: 'trx_count'),
          ),
        )
        .toList();
  }

  Future<List<ReportNamedAmount>> _salesByCashier(
    Database db, {
    required ReportQuery query,
    required _SqlParts sales,
    required _SqlParts items,
  }) async {
    final String sql = query.hasLineFilter
        ? '''
SELECT COALESCE(t.user_id, '') AS id,
       $_cashierNameSql AS name,
       CAST(COUNT(DISTINCT t.id) AS INTEGER) AS trx_count,
       CAST(COALESCE(SUM(ti.line_total), 0) AS INTEGER) AS amount
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = ti.product_id
LEFT JOIN ${DatabaseConstants.tableLocalUsers} lu ON lu.id = t.user_id
LEFT JOIN ${DatabaseConstants.tableUsers} u ON u.id = t.user_id
WHERE ${items.where}
GROUP BY t.user_id, $_cashierNameSql
ORDER BY amount DESC, name COLLATE NOCASE ASC
'''
        : '''
SELECT COALESCE(t.user_id, '') AS id,
       $_cashierNameSql AS name,
       CAST(COUNT(*) AS INTEGER) AS trx_count,
       CAST(COALESCE(SUM(t.total_amount), 0) AS INTEGER) AS amount
FROM ${DatabaseConstants.tableTransactions} t
LEFT JOIN ${DatabaseConstants.tableLocalUsers} lu ON lu.id = t.user_id
LEFT JOIN ${DatabaseConstants.tableUsers} u ON u.id = t.user_id
WHERE ${sales.where}
GROUP BY t.user_id, $_cashierNameSql
ORDER BY amount DESC, name COLLATE NOCASE ASC
''';
    final rows = await db.rawQuery(
      sql,
      query.hasLineFilter ? items.args : sales.args,
    );
    return rows.map(_namedFromRow).toList();
  }

  Future<List<ReportNamedAmount>> _salesByCategory(
    Database db, {
    required _SqlParts items,
  }) async {
    final rows = await db.rawQuery('''
SELECT COALESCE(p.category_id, '') AS id,
       COALESCE(c.name, 'Tanpa kategori') AS name,
       CAST(COALESCE(SUM(ti.qty), 0) AS INTEGER) AS qty,
       CAST(COALESCE(SUM(ti.line_total), 0) AS INTEGER) AS amount
FROM ${DatabaseConstants.tableTransactionItems} ti
INNER JOIN ${DatabaseConstants.tableTransactions} t
  ON t.id = ti.transaction_id
LEFT JOIN ${DatabaseConstants.tableProducts} p ON p.id = ti.product_id
LEFT JOIN ${DatabaseConstants.tableCategories} c ON c.id = p.category_id
WHERE ${items.where}
GROUP BY p.category_id, c.name
ORDER BY amount DESC, name COLLATE NOCASE ASC
''', items.args);
    return rows.map(_namedFromRow).toList();
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

  ReportNamedAmount _namedFromRow(Map<String, Object?> row) {
    return ReportNamedAmount(
      id: row['id']! as String,
      name: row['name']! as String,
      amount: _asInt(row['amount'], field: 'amount'),
      qty: _asInt(row['qty'], field: 'qty'),
      count: _asInt(row['trx_count'], field: 'trx_count'),
      cogs: _asInt(row['cogs'], field: 'cogs'),
      grossProfit: _asInt(row['gross_profit'], field: 'gross_profit'),
    );
  }

  Future<int> _scalarInt(Database db, String sql, List<Object> args) async {
    final rows = await db.rawQuery(sql, args);
    if (rows.isEmpty) {
      return 0;
    }
    return _asInt(rows.first.values.first, field: 'value');
  }

  /// Tolak double/num pecahan agar laporan tidak “benar kelihatannya”.
  int _asInt(Object? value, {required String field}) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    throw StateError(
      'Nilai laporan $field harus integer SQLite, bukan $value '
      '(${value.runtimeType})',
    );
  }

  String _paymentLabel(String storage) {
    try {
      return PaymentMethod.parse(storage).label;
    } catch (_) {
      return storage;
    }
  }
}

final class _SqlParts {
  const _SqlParts({required this.where, required this.args});

  final String where;
  final List<Object> args;

  /// Filter transaksi. Filter metode: transaksi yang punya pembayaran itu
  /// (campuran tunai+QRIS tetap masuk utuh jika filter tunai).
  static _SqlParts sales({
    required String businessId,
    required ReportQuery query,
  }) {
    final List<String> clauses = <String>[
      't.business_id = ?',
      "t.status = 'completed'",
      't.created_at >= ?',
      't.created_at < ?',
    ];
    final List<Object> args = <Object>[
      businessId,
      query.range.startMs,
      query.range.endMsExclusive,
    ];
    if (query.cashierId != null) {
      if (query.cashierId == ReportFilter.noCashierId) {
        clauses.add('t.user_id IS NULL');
      } else {
        clauses.add('t.user_id = ?');
        args.add(query.cashierId!);
      }
    }
    if (query.paymentMethod != null) {
      clauses.add('''EXISTS (
        SELECT 1 FROM ${DatabaseConstants.tablePayments} pf
        WHERE pf.transaction_id = t.id AND pf.method = ?
      )''');
      args.add(query.paymentMethod!);
    }
    if (query.productId != null) {
      clauses.add('''EXISTS (
        SELECT 1 FROM ${DatabaseConstants.tableTransactionItems} tif
        WHERE tif.transaction_id = t.id AND tif.product_id = ?
      )''');
      args.add(query.productId!);
    }
    if (query.categoryId != null) {
      clauses.add('''EXISTS (
        SELECT 1 FROM ${DatabaseConstants.tableTransactionItems} tif
        INNER JOIN ${DatabaseConstants.tableProducts} pf ON pf.id = tif.product_id
        WHERE tif.transaction_id = t.id AND pf.category_id = ?
      )''');
      args.add(query.categoryId!);
    }
    return _SqlParts(where: clauses.join('\n  AND '), args: args);
  }

  static _SqlParts items({
    required String businessId,
    required ReportQuery query,
  }) {
    final _SqlParts base = sales(businessId: businessId, query: query);
    if (!query.hasLineFilter) {
      return base;
    }
    final List<String> extra = <String>[];
    final List<Object> args = List<Object>.from(base.args);
    if (query.productId != null) {
      extra.add('ti.product_id = ?');
      args.add(query.productId!);
    }
    if (query.categoryId != null) {
      extra.add('p.category_id = ?');
      args.add(query.categoryId!);
    }
    return _SqlParts(
      where: '${base.where}\n  AND ${extra.join('\n  AND ')}',
      args: args,
    );
  }
}
