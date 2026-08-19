import 'package:flutter/material.dart';
import 'package:kasir_dapur/widgets/kd_coming_soon.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const KdComingSoonPage(
      title: 'Kategori',
      description: 'Pengelompokan produk akan tersedia pada tahap berikutnya.',
    );
  }
}
