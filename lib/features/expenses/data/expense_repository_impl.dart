import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
import 'package:kasir_dapur/features/expenses/domain/expense_repository.dart';
import 'package:kasir_dapur/features/sync/data/sync_repository_impl.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteExpenseRepository implements ExpenseRepository {
  SqliteExpenseRepository({
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
  Future<List<ExpenseCategory>> ensureDefaultCategories(
    String businessId,
  ) async {
    final Database db = await _database.database;
    final int now = _clock.nowEpochMs();
    await db.transaction((Transaction txn) async {
      for (final ({String code, String label}) row
          in ExpenseCategoryCatalog.defaults) {
        final existing = await txn.query(
          DatabaseConstants.tableExpenseCategories,
          where: 'business_id = ? AND code = ? AND deleted_at IS NULL',
          whereArgs: <Object>[businessId, row.code],
          limit: 1,
        );
        if (existing.isNotEmpty) {
          continue;
        }
        await txn.insert(
          DatabaseConstants.tableExpenseCategories,
          <String, Object>{
            'id': 'expcat-$businessId-${row.code}',
            'business_id': businessId,
            'name': row.label,
            'code': row.code,
            'created_at': now,
            'updated_at': now,
          },
        );
      }
    });
    return listCategories(businessId: businessId);
  }

  @override
  Future<List<ExpenseCategory>> listCategories({
    required String businessId,
  }) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableExpenseCategories,
      where: 'business_id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[businessId],
      orderBy: 'name COLLATE NOCASE ASC',
    );
    final List<ExpenseCategory> mapped = rows.map(_mapCategory).toList();
    mapped.sort((ExpenseCategory a, ExpenseCategory b) {
      return _order(a.code).compareTo(_order(b.code));
    });
    return mapped;
  }

  @override
  Future<ExpenseCategory> createCategory({
    required String businessId,
    required String name,
    String? code,
  }) async {
    if (name.trim().isEmpty) {
      throw const ValidationException('Nama kategori wajib diisi');
    }
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await (await _database.database).transaction((txn) async {
      await txn.insert(
        DatabaseConstants.tableExpenseCategories,
        <String, Object?>{
          'id': id,
          'business_id': businessId,
          'name': name.trim(),
          'code': code,
          'created_at': now,
          'updated_at': now,
        },
      );
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: businessId,
        aggregate: SyncAggregate.category,
        entityId: id,
      );
    });
    return ExpenseCategory(
      id: id,
      businessId: businessId,
      name: name.trim(),
      code: code,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<Expense> create(NewExpense input) async {
    if (input.amount <= 0) {
      throw const ValidationException('Nominal pengeluaran harus integer > 0');
    }
    final String id = _uuid.v4();
    final int now = _clock.nowEpochMs();
    await (await _database.database).transaction((Transaction txn) async {
      await txn.insert(DatabaseConstants.tableExpenses, <String, Object?>{
        'id': id,
        'business_id': input.businessId,
        'category_id': input.categoryId,
        'amount': input.amount,
        'note': input.note,
        'spent_at': input.spentAt,
        'created_at': now,
        'updated_at': now,
      });
      await enqueueEntity(
        txn,
        clock: _clock,
        uuid: _uuid,
        businessId: input.businessId,
        aggregate: SyncAggregate.expense,
        entityId: id,
      );
    });
    return (await _getById(id))!;
  }

  @override
  Future<List<Expense>> list({
    required String businessId,
    String? categoryId,
  }) async {
    final StringBuffer where = StringBuffer(
      'e.business_id = ? AND e.deleted_at IS NULL',
    );
    final List<Object> args = <Object>[businessId];
    if (categoryId != null && categoryId.isNotEmpty) {
      where.write(' AND e.category_id = ?');
      args.add(categoryId);
    }
    final rows = await (await _database.database).rawQuery('''
SELECT e.*, ec.name AS category_name, ec.code AS category_code
FROM ${DatabaseConstants.tableExpenses} e
LEFT JOIN ${DatabaseConstants.tableExpenseCategories} ec
  ON ec.id = e.category_id
WHERE $where
ORDER BY e.spent_at DESC
''', args);
    return rows.map(_mapExpense).toList();
  }

  @override
  Future<void> softDelete(String id) async {
    final int now = _clock.nowEpochMs();
    final int changed = await (await _database.database).update(
      DatabaseConstants.tableExpenses,
      <String, Object>{'deleted_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: <Object>[id],
    );
    if (changed == 0) {
      throw const NotFoundException('Pengeluaran tidak ditemukan');
    }
  }

  Future<Expense?> _getById(String id) async {
    final rows = await (await _database.database).rawQuery(
      '''
SELECT e.*, ec.name AS category_name, ec.code AS category_code
FROM ${DatabaseConstants.tableExpenses} e
LEFT JOIN ${DatabaseConstants.tableExpenseCategories} ec
  ON ec.id = e.category_id
WHERE e.id = ? AND e.deleted_at IS NULL
LIMIT 1
''',
      <Object>[id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapExpense(rows.first);
  }

  ExpenseCategory _mapCategory(Map<String, Object?> row) {
    return ExpenseCategory(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      name: readString(row['name'], field: 'name'),
      code: readStringOrNull(row['code']),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }

  Expense _mapExpense(Map<String, Object?> row) {
    return Expense(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      categoryId: readStringOrNull(row['category_id']),
      categoryName: readStringOrNull(row['category_name']),
      categoryCode: readStringOrNull(row['category_code']),
      amount: readMoney(row['amount'], field: 'amount'),
      note: readStringOrNull(row['note']),
      spentAt: readInt(row['spent_at'], field: 'spent_at'),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }

  int _order(String? code) {
    if (code == null) {
      return ExpenseCategoryCatalog.defaults.length;
    }
    final int index = ExpenseCategoryCatalog.defaults.indexWhere(
      (({String code, String label}) row) => row.code == code,
    );
    return index < 0 ? ExpenseCategoryCatalog.defaults.length : index;
  }
}
