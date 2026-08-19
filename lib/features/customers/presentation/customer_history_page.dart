import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/core/errors/error_handler.dart';
import 'package:kasir_dapur/features/customers/domain/customer.dart';
import 'package:kasir_dapur/features/customers/presentation/customers_controller.dart';
import 'package:kasir_dapur/shared/formatters/date_formatter.dart';
import 'package:kasir_dapur/shared/formatters/money_formatter.dart';
import 'package:kasir_dapur/widgets/kd_empty_state.dart';
import 'package:kasir_dapur/widgets/kd_error_state.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';
import 'package:kasir_dapur/widgets/kd_loading.dart';
import 'package:kasir_dapur/widgets/kd_section_card.dart';

class CustomerHistoryPage extends ConsumerWidget {
  const CustomerHistoryPage({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CustomerSaleHistory>> history = ref.watch(
      customerSalesHistoryProvider(customer.id),
    );
    return Scaffold(
      appBar: AppBar(title: Text('History · ${customer.name}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          KdSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (customer.phone != null) Text(customer.phone!),
                const SizedBox(height: 12),
                Text('Total transaksi: ${customer.transactionCount}'),
                Text(
                  'Total belanja: ${MoneyFormatter.rupiah(customer.spendTotal)}',
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${customer.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Riwayat transaksi',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: KdLoadingView(message: 'Memuat riwayat...'),
            ),
            error: (Object error, StackTrace _) {
              return KdErrorState(
                title: 'Riwayat gagal dimuat',
                subtitle: ErrorHandler.userMessage(error),
                onRetry: () =>
                    ref.invalidate(customerSalesHistoryProvider(customer.id)),
              );
            },
            data: (List<CustomerSaleHistory> items) {
              if (items.isEmpty) {
                return const KdEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Belum ada transaksi',
                  subtitle: 'Penjualan kasir yang memakai pelanggan ini akan muncul di sini.',
                );
              }
              return Column(
                children: [
                  for (final CustomerSaleHistory row in items)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(MoneyFormatter.rupiah(row.totalAmount)),
                      subtitle: Text(
                        DateFormatter.dateTimeId(
                          DateTime.fromMillisecondsSinceEpoch(row.createdAt),
                        ),
                      ),
                      trailing: Text(row.status),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const KdLegalFooter(),
        ],
      ),
    );
  }
}
