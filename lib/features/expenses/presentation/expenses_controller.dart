import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';

final expenseCategoryFilterProvider = StateProvider<String?>((Ref ref) => null);

final expenseCategoriesProvider = FutureProvider<List<ExpenseCategory>>((
  Ref ref,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref
      .watch(expenseRepositoryProvider)
      .ensureDefaultCategories(businessId);
});

final expensesListProvider = FutureProvider<List<Expense>>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  final String? categoryId = ref.watch(expenseCategoryFilterProvider);
  await ref.watch(expenseCategoriesProvider.future);
  return ref
      .watch(expenseRepositoryProvider)
      .list(businessId: businessId, categoryId: categoryId);
});

final class ExpenseController {
  ExpenseController(this._ref);

  final Ref _ref;

  Future<Expense> add({
    required String businessId,
    required int amount,
    required String categoryId,
    String? note,
    required int spentAt,
  }) async {
    final Expense saved = await _ref
        .read(expenseRepositoryProvider)
        .create(
          NewExpense(
            businessId: businessId,
            amount: amount,
            categoryId: categoryId,
            note: note,
            spentAt: spentAt,
          ),
        );
    _ref.invalidate(expensesListProvider);
    return saved;
  }
}

final expenseControllerProvider = Provider<ExpenseController>((Ref ref) {
  return ExpenseController(ref);
});
