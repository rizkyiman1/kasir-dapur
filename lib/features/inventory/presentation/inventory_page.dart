import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/app/routes.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/inventory/domain/stock_repository.dart';
import 'package:kasir_dapur/features/inventory/presentation/inventory_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

class InventoryPage extends ConsumerWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StockPosition>> positions = ref.watch(
      inventoryPositionsProvider,
    );
    final InventoryListFilter filter = ref.watch(inventoryListFilterProvider);
    final AsyncValue<bool> allowNegative = ref.watch(
      allowNegativeStockProvider,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stok'),
        actions: [
          IconButton(
            tooltip: 'Histori stok',
            onPressed: () => context.push(AppRoutes.stockHistory),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Stock opname',
            onPressed: () => context.push(AppRoutes.stockOpname),
            icon: const Icon(Icons.fact_check_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama, SKU, atau barcode',
              ),
              onChanged: (String value) {
                ref.read(inventoryQueryProvider.notifier).state = value;
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Semua'),
                    selected: filter == InventoryListFilter.all,
                    onSelected: (_) {
                      ref.read(inventoryListFilterProvider.notifier).state =
                          InventoryListFilter.all;
                    },
                  ),
                  FilterChip(
                    label: const Text('Menipis'),
                    selected: filter == InventoryListFilter.lowStock,
                    onSelected: (_) {
                      ref.read(inventoryListFilterProvider.notifier).state =
                          InventoryListFilter.lowStock;
                    },
                  ),
                ],
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            title: const Text('Izinkan stok negatif'),
            subtitle: const Text(
              'Jika nonaktif, transaksi tidak boleh melebihi stok',
            ),
            value: allowNegative.asData?.value ?? false,
            onChanged: allowNegative.isLoading
                ? null
                : (bool value) {
                    unawaited(_setAllowNegative(context, ref, value));
                  },
          ),
          Expanded(
            child: positions.when(
              skipLoadingOnReload: true,
              loading: () => const KdLoadingView(message: 'Memuat stok...'),
              error: (Object error, StackTrace _) {
                return KdErrorState(
                  title: 'Stok gagal dimuat',
                  subtitle: ErrorHandler.userMessage(error),
                  onRetry: () => ref.invalidate(inventoryPositionsProvider),
                );
              },
              data: (List<StockPosition> items) {
                if (items.isEmpty) {
                  return const KdEmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'Belum ada stok',
                    subtitle:
                        'Tambah produk terlebih dahulu, lalu catat stok masuk.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(inventoryPositionsProvider);
                    await ref.read(inventoryPositionsProvider.future);
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (BuildContext context, int index) {
                      if (index == items.length) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: KdLegalFooter(),
                        );
                      }
                      final StockPosition item = items[index];
                      return _StockTile(
                        item: item,
                        onChanged: () {
                          ref.invalidate(inventoryPositionsProvider);
                          ref.invalidate(allowNegativeStockProvider);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setAllowNegative(
    BuildContext context,
    WidgetRef ref,
    bool allow,
  ) async {
    try {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      await ref
          .read(stockRepositoryProvider)
          .setAllowNegativeStock(businessId: businessId, allow: allow);
      ref.invalidate(allowNegativeStockProvider);
      if (context.mounted) {
        context.showMessage(
          allow ? 'Stok negatif diizinkan' : 'Stok negatif dinonaktifkan',
        );
      }
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }
}

class _StockTile extends ConsumerWidget {
  const _StockTile({required this.item, required this.onChanged});

  final StockPosition item;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name),
      subtitle: Text(
        [
          if (item.sku != null) 'SKU ${item.sku}',
          'Min. ${item.minStock}',
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.isLow)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Menipis'),
                visualDensity: VisualDensity.compact,
                backgroundColor: scheme.errorContainer,
                labelStyle: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          Text(
            '${item.qty}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: item.isLow || item.qty < 0 ? scheme.error : null,
            ),
          ),
          IconButton(
            tooltip: 'Menu stok',
            onPressed: () => unawaited(_openActions(context, ref)),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      onTap: () => unawaited(_openActions(context, ref)),
    );
  }

  Future<void> _openActions(BuildContext context, WidgetRef ref) async {
    final _StockAction? action = await showModalBottomSheet<_StockAction>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(item.name),
                subtitle: Text('Stok ${item.qty} · Min. ${item.minStock}'),
              ),
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Stok masuk'),
                onTap: () => Navigator.pop(context, _StockAction.stockIn),
              ),
              ListTile(
                leading: const Icon(Icons.remove_circle_outline),
                title: const Text('Stok keluar'),
                onTap: () => Navigator.pop(context, _StockAction.stockOut),
              ),
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Penyesuaian / opname item'),
                onTap: () => Navigator.pop(context, _StockAction.adjust),
              ),
              ListTile(
                leading: const Icon(Icons.shopping_bag_outlined),
                title: const Text('Pembelian'),
                onTap: () => Navigator.pop(context, _StockAction.purchase),
              ),
              ListTile(
                leading: const Icon(Icons.assignment_return_outlined),
                title: const Text('Retur penjualan'),
                onTap: () => Navigator.pop(context, _StockAction.saleReturn),
              ),
              ListTile(
                leading: const Icon(Icons.broken_image_outlined),
                title: const Text('Rusak'),
                onTap: () => Navigator.pop(context, _StockAction.damaged),
              ),
              ListTile(
                leading: const Icon(Icons.event_busy_outlined),
                title: const Text('Kadaluarsa'),
                onTap: () => Navigator.pop(context, _StockAction.expired),
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Transfer'),
                onTap: () => Navigator.pop(context, _StockAction.transfer),
              ),
              ListTile(
                leading: const Icon(Icons.table_chart_outlined),
                title: const Text('Kartu stok'),
                onTap: () => Navigator.pop(context, _StockAction.card),
              ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) {
      return;
    }
    if (action == _StockAction.card) {
      unawaited(
        context.push('${AppRoutes.stockCard}?productId=${item.productId}'),
      );
      return;
    }
    await _runAction(context, ref, action);
  }

  Future<void> _runAction(
    BuildContext context,
    WidgetRef ref,
    _StockAction action,
  ) async {
    final bool transfer = action == _StockAction.transfer;
    final bool adjust = action == _StockAction.adjust;
    final _QtyResult? result = await showDialog<_QtyResult>(
      context: context,
      builder: (BuildContext context) {
        return _QtyDialog(
          title: action.title,
          counted: adjust,
          allowNegativeDelta: transfer,
        );
      },
    );
    if (result == null) {
      return;
    }
    try {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      final StockRepository repo = ref.read(stockRepositoryProvider);
      switch (action) {
        case _StockAction.stockIn:
          await repo.stockIn(
            businessId: businessId,
            productId: item.productId,
            qty: result.qty,
            note: result.note,
          );
        case _StockAction.stockOut:
          await repo.stockOut(
            businessId: businessId,
            productId: item.productId,
            qty: result.qty,
            note: result.note,
          );
        case _StockAction.adjust:
          await repo.adjustTo(
            businessId: businessId,
            productId: item.productId,
            countedQty: result.qty,
            note: result.note,
          );
        case _StockAction.purchase:
          await repo.purchase(
            businessId: businessId,
            productId: item.productId,
            qty: result.qty,
            note: result.note,
          );
        case _StockAction.saleReturn:
          await repo.saleReturn(
            businessId: businessId,
            productId: item.productId,
            qty: result.qty,
            note: result.note,
          );
        case _StockAction.damaged:
          await repo.recordDamaged(
            businessId: businessId,
            productId: item.productId,
            qty: result.qty,
            note: result.note,
          );
        case _StockAction.expired:
          await repo.recordExpired(
            businessId: businessId,
            productId: item.productId,
            qty: result.qty,
            note: result.note,
          );
        case _StockAction.transfer:
          await repo.transfer(
            businessId: businessId,
            productId: item.productId,
            qtyDelta: result.signedQty,
            note: result.note,
          );
        case _StockAction.card:
          break;
      }
      onChanged();
      if (context.mounted) {
        context.showMessage('Stok diperbarui');
      }
    } catch (error) {
      if (context.mounted) {
        context.showError(error);
      }
    }
  }
}

enum _StockAction {
  stockIn,
  stockOut,
  adjust,
  purchase,
  saleReturn,
  damaged,
  expired,
  transfer,
  card;

  String get title {
    return switch (this) {
      _StockAction.stockIn => 'Stok masuk',
      _StockAction.stockOut => 'Stok keluar',
      _StockAction.adjust => 'Stok fisik',
      _StockAction.purchase => 'Pembelian',
      _StockAction.saleReturn => 'Retur penjualan',
      _StockAction.damaged => 'Barang rusak',
      _StockAction.expired => 'Kadaluarsa',
      _StockAction.transfer => 'Transfer',
      _StockAction.card => 'Kartu stok',
    };
  }
}

final class _QtyResult {
  const _QtyResult({required this.qty, required this.signedQty, this.note});

  final int qty;
  final int signedQty;
  final String? note;
}

class _QtyDialog extends StatefulWidget {
  const _QtyDialog({
    required this.title,
    this.counted = false,
    this.allowNegativeDelta = false,
  });

  final String title;
  final bool counted;
  final bool allowNegativeDelta;

  @override
  State<_QtyDialog> createState() => _QtyDialogState();
}

class _QtyDialogState extends State<_QtyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _qty = TextEditingController();
  final TextEditingController _note = TextEditingController();
  bool _transferOut = true;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            KdTextField(
              label: widget.counted ? 'Stok fisik' : 'Kuantitas',
              controller: _qty,
              keyboardType: TextInputType.number,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: widget.counted
                  ? AppValidators.nonNegativeInt
                  : AppValidators.positiveInt,
            ),
            if (widget.allowNegativeDelta) ...[
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Keluar')),
                  ButtonSegment(value: false, label: Text('Masuk')),
                ],
                selected: <bool>{_transferOut},
                onSelectionChanged: (Set<bool> value) {
                  setState(() => _transferOut = value.first);
                },
              ),
            ],
            const SizedBox(height: 12),
            KdTextField(label: 'Catatan (opsional)', controller: _note),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) {
              return;
            }
            final int qty = int.parse(_qty.text.trim());
            final int signed = widget.allowNegativeDelta && _transferOut
                ? -qty
                : qty;
            Navigator.pop(
              context,
              _QtyResult(
                qty: qty,
                signedQty: signed,
                note: _note.text.trim().isEmpty ? null : _note.text.trim(),
              ),
            );
          },
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
