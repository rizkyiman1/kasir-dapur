import 'package:flutter/material.dart';
import 'package:kasir_dapur/widgets/kd_coming_soon.dart';

class TransactionsPage extends StatelessWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const KdComingSoonPage(
      title: 'Transaksi',
      description:
          'Riwayat penjualan dan void akan tersedia pada tahap berikutnya.',
    );
  }
}
