import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/expenses/domain/expense.dart';
import 'package:kasir_dapur/features/expenses/presentation/expenses_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/presentation/entitlement_page.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class ExpensesPage extends ConsumerWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const EntitlementPage(
      feature: FeatureKey.expenses,
      child: _ExpensesBody(),
    );
  }
}

class _ExpensesBody extends ConsumerWidget {
  const _ExpensesBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Expense>> list = ref.watch(expensesListProvider);
    final AsyncValue<List<ExpenseCategory>> categories = ref.watch(
      expenseCategoriesProvider,
    );
    final String? filter = ref.watch(expenseCategoryFilterProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengeluaran'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_add(context, ref)),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          categories.maybeWhen(
            data: (List<ExpenseCategory> items) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: const Text('Semua'),
                      selected: filter == null,
                      onSelected: (_) {
                        ref.read(expenseCategoryFilterProvider.notifier).state =
                            null;
                      },
                    ),
                    for (final ExpenseCategory category in items)
                      FilterChip(
                        label: Text(category.label),
                        selected: filter == category.id,
                        onSelected: (_) {
                          ref
                                  .read(expenseCategoryFilterProvider.notifier)
                                  .state =
                              category.id;
                        },
                      ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: list.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const KdLoadingView(message: 'Memuat pengeluaran...'),
              error: (Object error, StackTrace _) {
                return KdErrorState(
                  title: 'Pengeluaran gagal dimuat',
                  subtitle: ErrorHandler.userMessage(error),
                  onRetry: () => ref.invalidate(expensesListProvider),
                );
              },
              data: (List<Expense> items) {
                if (items.isEmpty) {
                  return const KdEmptyState(
                    icon: Icons.payments_outlined,
                    title: 'Belum ada pengeluaran',
                    subtitle: 'Catat listrik, gas, packaging, gaji, dan biaya usaha lain.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == items.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: KdLegalFooter(),
                      );
                    }
                    final Expense row = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.categoryLabel),
                      subtitle: Text(
                        [
                          DateFormatter.dateId(
                            DateTime.fromMillisecondsSinceEpoch(row.spentAt),
                          ),
                          if (row.note != null && row.note!.isNotEmpty)
                            row.note!,
                        ].join(' · '),
                      ),
                      trailing: Text(MoneyFormatter.rupiah(row.amount)),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final List<ExpenseCategory> categories =
        ref.read(expenseCategoriesProvider).asData?.value ??
        await ref.read(expenseCategoriesProvider.future);
    if (!context.mounted || categories.isEmpty) {
      return;
    }
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            _ExpenseEditorPage(categories: categories),
      ),
    );
    if (saved == true) {
      ref.invalidate(expensesListProvider);
    }
  }
}

class _ExpenseEditorPage extends ConsumerStatefulWidget {
  const _ExpenseEditorPage({required this.categories});

  final List<ExpenseCategory> categories;

  @override
  ConsumerState<_ExpenseEditorPage> createState() => _ExpenseEditorPageState();
}

class _ExpenseEditorPageState extends ConsumerState<_ExpenseEditorPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  late String _categoryId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengeluaran baru')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: [
                for (final ExpenseCategory category in widget.categories)
                  DropdownMenuItem<String>(
                    value: category.id,
                    child: Text(category.label),
                  ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() => _categoryId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            KdTextField(
              label: 'Nominal (Rp)',
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: AppValidators.rupiahInteger,
            ),
            const SizedBox(height: 12),
            KdTextField(
              label: 'Catatan',
              controller: _note,
              hint: 'Opsional',
              minLines: 2,
              maxLines: 3,
              maxLength: 200,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : () => unawaited(_save()),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      await ref
          .read(expenseControllerProvider)
          .add(
            businessId: businessId,
            amount: AppValidators.parseRupiah(_amount.text),
            categoryId: _categoryId,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            spentAt: ref.read(clockProvider).nowEpochMs(),
          );
      if (!mounted) {
        return;
      }
      context.showMessage('Pengeluaran disimpan.');
      Navigator.of(context).pop(true);
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      context.showMessage(ErrorHandler.userMessage(error));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
