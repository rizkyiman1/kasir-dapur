import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/inventory/domain/stock.dart';
import 'package:kasir_dapur/features/inventory/presentation/inventory_controller.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';

class StockHistoryPage extends ConsumerWidget {
  const StockHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<StockMovement>> history = ref.watch(
      stockHistoryProvider,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Histori stok')),
      body: history.when(
        loading: () => const KdLoadingView(message: 'Memuat histori...'),
        error: (Object error, StackTrace _) {
          return KdErrorState(
            title: 'Histori gagal dimuat',
            subtitle: ErrorHandler.userMessage(error),
            onRetry: () => ref.invalidate(stockHistoryProvider),
          );
        },
        data: (List<StockMovement> items) {
          if (items.isEmpty) {
            return const KdEmptyState(
              icon: Icons.history,
              title: 'Belum ada histori',
              subtitle: 'Setiap perubahan stok akan tercatat di sini.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              if (index == items.length) {
                return const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: KdLegalFooter(),
                );
              }
              final StockMovement row = items[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(row.productName ?? row.productId),
                subtitle: Text(
                  [
                    row.typeLabel,
                    DateFormatter.dateTimeId(
                      DateTime.fromMillisecondsSinceEpoch(row.createdAt),
                    ),
                    if (row.note != null && row.note!.isNotEmpty) row.note!,
                  ].join(' · '),
                ),
                trailing: Text(
                  '${row.qtyBefore} → ${row.qtyAfter}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
