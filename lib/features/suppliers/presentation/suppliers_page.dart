import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/presentation/entitlement_page.dart';
import 'package:kasir_dapur/features/suppliers/domain/supplier.dart';
import 'package:kasir_dapur/features/suppliers/presentation/supplier_editor_page.dart';
import 'package:kasir_dapur/features/suppliers/presentation/supplier_history_page.dart';
import 'package:kasir_dapur/features/suppliers/presentation/suppliers_controller.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';

class SuppliersPage extends ConsumerWidget {
  const SuppliersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const EntitlementPage(
      feature: FeatureKey.suppliers,
      child: _SuppliersBody(),
    );
  }
}

class _SuppliersBody extends ConsumerWidget {
  const _SuppliersBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Supplier>> list = ref.watch(suppliersListProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pemasok'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_openEditor(context)),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama atau kontak',
              ),
              onChanged: (String value) {
                ref.read(supplierQueryProvider.notifier).state = value;
              },
            ),
          ),
          Expanded(
            child: list.when(
              skipLoadingOnReload: true,
              loading: () => const KdLoadingView(message: 'Memuat pemasok...'),
              error: (Object error, StackTrace _) {
                return KdErrorState(
                  title: 'Pemasok gagal dimuat',
                  subtitle: ErrorHandler.userMessage(error),
                  onRetry: () => ref.invalidate(suppliersListProvider),
                );
              },
              data: (List<Supplier> items) {
                if (items.isEmpty) {
                  return const KdEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'Belum ada pemasok',
                    subtitle: 'Tambah pemasok dengan nama. Kontak dan alamat opsional.',
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
                    final Supplier row = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(row.name),
                      subtitle: Text(row.contact ?? 'Tanpa kontak'),
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

  Future<void> _openEditor(BuildContext context, [Supplier? existing]) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            SupplierEditorPage(existing: existing),
      ),
    );
  }

  Future<void> _openHistory(BuildContext context, Supplier supplier) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            SupplierHistoryPage(supplier: supplier),
      ),
    );
  }
}
