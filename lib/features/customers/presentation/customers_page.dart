import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/customers/presentation/customer_editor_page.dart';
import 'package:kasir_dapur/features/customers/presentation/customer_history_page.dart';
import 'package:kasir_dapur/features/customers/presentation/customers_controller.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/presentation/entitlement_page.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';

class CustomersPage extends ConsumerWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const EntitlementPage(
      feature: FeatureKey.customers,
      child: _CustomersBody(),
    );
  }
}

class _CustomersBody extends ConsumerWidget {
  const _CustomersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Customer>> list = ref.watch(customersListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelanggan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_openEditor(context)),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama atau nomor HP',
              ),
              onChanged: (String value) {
                ref.read(customerQueryProvider.notifier).state = value;
              },
            ),
          ),
          Expanded(
            child: list.when(
              skipLoadingOnReload: true,
              loading: () =>
                  const KdLoadingView(message: 'Memuat pelanggan...'),
              error: (Object error, StackTrace _) {
                return KdErrorState(
                  title: 'Pelanggan gagal dimuat',
                  subtitle: ErrorHandler.userMessage(error),
                  onRetry: () => ref.invalidate(customersListProvider),
                );
              },
              data: (List<Customer> items) {
                if (items.isEmpty) {
                  return const KdEmptyState(
                    icon: Icons.people_outline,
                    title: 'Belum ada pelanggan',
                    subtitle: 'Tambah pelanggan dengan nama. Nomor HP dan alamat opsional.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                  itemCount: items.length + 1,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    if (index == items.length) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 24),
                        child: KdLegalFooter(),
                      );
                    }
                    final Customer row = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.name),
                      subtitle: Text(_subtitle(row)),
                      onTap: () => unawaited(_openEditor(context, row)),
                      trailing: IconButton(
                        tooltip: 'History',
                        icon: const Icon(Icons.history),
                        onPressed: () => unawaited(_openHistory(context, row)),
                      ),
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

  String _subtitle(Customer row) {
    final String phone = row.phone ?? 'Tanpa nomor HP';
    return '$phone · ${row.transactionCount} transaksi · '
        '${MoneyFormatter.rupiah(row.spendTotal)}';
  }

  Future<void> _openEditor(BuildContext context, [Customer? existing]) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CustomerEditorPage(existing: existing),
      ),
    );
  }

  Future<void> _openHistory(BuildContext context, Customer customer) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            CustomerHistoryPage(customer: customer),
      ),
    );
  }
}
