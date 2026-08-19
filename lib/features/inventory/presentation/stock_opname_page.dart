import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/inventory/presentation/inventory_controller.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';

class StockOpnamePage extends ConsumerStatefulWidget {
  const StockOpnamePage({super.key});

  @override
  ConsumerState<StockOpnamePage> createState() => _StockOpnamePageState();
}

class _StockOpnamePageState extends ConsumerState<StockOpnamePage> {
  final Map<String, TextEditingController> _counts = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final TextEditingController controller in _counts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(StockPosition item) {
    return _counts.putIfAbsent(
      item.productId,
      () => TextEditingController(text: '${item.qty}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<StockPosition>> positions = ref.watch(
      inventoryPositionsProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Stock opname')),
      body: positions.when(
        loading: () => const KdLoadingView(message: 'Memuat item opname...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Opname gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(inventoryPositionsProvider),
          );
        },
        data: (List<StockPosition> items) {
          if (items.isEmpty) {
            return const KdEmptyState(
              icon: Icons.fact_check_outlined,
              title: 'Tidak ada produk',
              subtitle: 'Tambah produk sebelum melakukan stock opname.',
            );
          }
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'Isi stok fisik. Selisih akan dicatat sebagai penyesuaian dalam satu transaksi.',
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (BuildContext context, int index) {
                    final StockPosition item = items[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.name),
                      subtitle: Text(
                        'Sistem: ${item.qty} · Min. ${item.minStock}',
                      ),
                      trailing: SizedBox(
                        width: 88,
                        child: TextFormField(
                          controller: _controllerFor(item),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(labelText: 'Fisik'),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: FilledButton(
                  onPressed: _saving ? null : () => _submit(items),
                  child: Text(_saving ? 'Menyimpan...' : 'Simpan opname'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submit(List<StockPosition> items) async {
    final List<StockOpnameLine> lines = [];
    for (final StockPosition item in items) {
      final String raw = _controllerFor(item).text.trim();
      final String? error = AppValidators.nonNegativeInt(
        raw,
        fieldName: item.name,
      );
      if (error != null) {
        context.showMessage(error);
        return;
      }
      lines.add(
        StockOpnameLine(productId: item.productId, countedQty: int.parse(raw)),
      );
    }
    setState(() => _saving = true);
    try {
      final String businessId = await ref.read(activeBusinessIdProvider.future);
      final StockOpnameResult result = await ref
          .read(stockRepositoryProvider)
          .commitOpname(
            businessId: businessId,
            lines: lines,
            note: 'Stock opname',
          );
      ref.invalidate(inventoryPositionsProvider);
      ref.invalidate(stockHistoryProvider);
      if (mounted) {
        context.showMessage(
          'Opname selesai. ${result.adjustedCount} disesuaikan, ${result.unchangedCount} tetap.',
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        context.showError(error);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
