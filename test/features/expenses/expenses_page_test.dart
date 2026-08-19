import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/auth/domain/auth_user.dart';
import 'package:kasir_dapur/features/auth/presentation/auth_controller.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
import 'package:kasir_dapur/features/expenses/domain/expense_repository.dart';
import 'package:kasir_dapur/features/expenses/presentation/expenses_page.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/presentation/subscription_controller.dart';

void main() {
  const AuthUser owner = AuthUser(
    id: 'o1',
    displayName: 'Budi',
    role: UserRole.owner,
  );

  testWidgets('halaman pengeluaran menampilkan kategori default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final _FakeExpenseRepository repo = _FakeExpenseRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => SeededAuthController(user: owner),
          ),
          featureGateProvider.overrideWith(
            (Ref ref) async => FeatureGate.forPlan(Plan.pro),
          ),
          activeBusinessIdProvider.overrideWith((Ref ref) async => 'biz-1'),
          expenseRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(home: ExpensesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Listrik'), findsWidgets);
    expect(find.text('Gas'), findsWidgets);
    expect(find.text('Packaging'), findsWidgets);
    expect(find.text('Transport'), findsWidgets);
    expect(find.text('Gaji'), findsWidgets);
    expect(find.text('Sewa'), findsWidgets);
    expect(find.text('Internet'), findsWidgets);
    expect(find.text('Lainnya'), findsWidgets);
    expect(find.text('Tambah'), findsOneWidget);
  });
}

final class _FakeExpenseRepository implements ExpenseRepository {
  late final List<ExpenseCategory> categories = [
    for (final ({String code, String label}) row
        in ExpenseCategoryCatalog.defaults)
      ExpenseCategory(
        id: row.code,
        businessId: 'biz-1',
        name: row.label,
        code: row.code,
        createdAt: 1,
        updatedAt: 1,
      ),
  ];

  @override
  Future<List<ExpenseCategory>> ensureDefaultCategories(
    String businessId,
  ) async => categories;

  @override
  Future<List<ExpenseCategory>> listCategories({
    required String businessId,
  }) async => categories;

  @override
  Future<ExpenseCategory> createCategory({
    required String businessId,
    required String name,
    String? code,
  }) async => categories.first;

  @override
  Future<Expense> create(NewExpense input) async {
    return Expense(
      id: 'e1',
      businessId: input.businessId,
      categoryId: input.categoryId,
      amount: input.amount,
      note: input.note,
      spentAt: input.spentAt,
      createdAt: 1,
      updatedAt: 1,
    );
  }

  @override
  Future<List<Expense>> list({
    required String businessId,
    String? categoryId,
  }) async => const <Expense>[];

  @override
  Future<void> softDelete(String id) async {}
}
