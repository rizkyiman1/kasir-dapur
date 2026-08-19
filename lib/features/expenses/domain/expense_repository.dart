import 'package:kasir_dapur/features/expenses/domain/expense.dart';

abstract class ExpenseRepository {
  Future<List<ExpenseCategory>> ensureDefaultCategories(String businessId);

  Future<List<ExpenseCategory>> listCategories({required String businessId});

  Future<ExpenseCategory> createCategory({
    required String businessId,
    required String name,
    String? code,
  });

  Future<Expense> create(NewExpense input);

  Future<List<Expense>> list({required String businessId, String? categoryId});

  Future<void> softDelete(String id);
}
