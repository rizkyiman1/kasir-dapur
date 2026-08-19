import 'package:flutter/material.dart';
import 'package:kasir_dapur/widgets/kd_coming_soon.dart';

class ProductsPage extends StatelessWidget {
  const ProductsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const KdComingSoonPage(
      title: 'Produk',
      description: 'Katalog produk, SKU, harga, dan stok akan tersedia pada tahap berikutnya.',
    );
  }
}
