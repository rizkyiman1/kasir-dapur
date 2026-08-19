import 'package:flutter/material.dart';
import 'package:kasir_dapur/features/barcode/domain/unknown_barcode_choice.dart';

Future<UnknownBarcodeChoice?> showUnknownBarcodeSheet({
  required BuildContext context,
  required String barcode,
  required bool canAddProduct,
}) {
  return showModalBottomSheet<UnknownBarcodeChoice>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Barcode tidak ditemukan',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(barcode, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Tambah produk'),
                subtitle: Text(
                  canAddProduct
                      ? 'Buat produk baru dengan barcode ini'
                      : 'Hanya owner/admin yang dapat menambah produk',
                ),
                onTap: () {
                  if (!canAddProduct) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Minta owner/admin menambah produk, atau cari manual.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context, UnknownBarcodeChoice.addProduct);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.search),
                title: const Text('Cari manual'),
                subtitle: const Text('Cari nama atau SKU di katalog kasir'),
                onTap: () =>
                    Navigator.pop(context, UnknownBarcodeChoice.searchManual),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.close),
                title: const Text('Batal'),
                onTap: () =>
                    Navigator.pop(context, UnknownBarcodeChoice.cancel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
