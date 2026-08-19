import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/inventory/presentation/inventory_controller.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';

class StockCardPage extends ConsumerWidget {
  const StockCardPage({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StockMovement>> card = ref.watch(
      stockCardProvider(productId),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Kartu stok')),
      body: card.when(
        loading: () => const KdLoadingView(message: 'Memuat kartu stok...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Kartu stok gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(stockCardProvider(productId)),
          );
        },
        data: (List<StockMovement> items) {
          if (items.isEmpty) {
            return const KdEmptyState(
              icon: Icons.table_chart_outlined,
              title: 'Belum ada pergerakan',
              subtitle:
                  'Stok masuk, keluar, atau penjualan akan tampil di sini.',
            );
          }
          final String name = items.first.productName ?? 'Produk';
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              }
              final StockMovement row = items[index - 1];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.typeLabel),
                subtitle: Text(
                  [
                    DateFormatter.dateTimeId(
                      DateTime.fromMillisecondsSinceEpoch(row.createdAt),
                    ),
                    if (row.note != null && row.note!.isNotEmpty) row.note!,
                  ].join(' · '),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      row.qty > 0 ? '+${row.qty}' : '${row.qty}',
                      style: TextStyle(
                        color: row.qty >= 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${row.qtyBefore} → ${row.qtyAfter}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
