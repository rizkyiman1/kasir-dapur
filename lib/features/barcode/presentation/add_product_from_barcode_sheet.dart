import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kasir_dapur/core/validators/app_validators.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/products/domain/product_repository.dart';
import 'package:kasir_dapur/shared/extensions/context_ext.dart';
import 'package:kasir_dapur/widgets/kd_button.dart';
import 'package:kasir_dapur/widgets/kd_text_field.dart';

Future<Product?> showAddProductFromBarcodeSheet({
  required BuildContext context,
  required String businessId,
  required String barcode,
  required ProductRepository products,
}) {
  return showModalBottomSheet<Product>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) {
      return _AddProductFromBarcodeSheet(
        businessId: businessId,
        barcode: barcode,
        products: products,
      );
    },
  );
}

class _AddProductFromBarcodeSheet extends StatefulWidget {
  const _AddProductFromBarcodeSheet({
    required this.businessId,
    required this.barcode,
    required this.products,
  });

  final String businessId;
  final String barcode;
  final ProductRepository products;

  @override
  State<_AddProductFromBarcodeSheet> createState() =>
      _AddProductFromBarcodeSheetState();
}

class _AddProductFromBarcodeSheetState
    extends State<_AddProductFromBarcodeSheet> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double inset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + inset),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tambah produk',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text('Barcode ${widget.barcode}'),
            const SizedBox(height: 12),
            KdTextField(
              label: 'Nama',
              controller: _name,
              validator: AppValidators.displayName,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            KdTextField(
              label: 'Harga jual',
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: AppValidators.rupiahInteger,
            ),
            const SizedBox(height: 16),
            KdButton(
              label: 'Simpan',
              loading: _saving,
              onPressed: _saving ? null : () => unawaited(_save()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    try {
      final Product product = await widget.products.create(
        NewProduct(
          businessId: widget.businessId,
          name: _name.text.trim(),
          barcode: widget.barcode,
          sellPrice: AppValidators.parseRupiah(_price.text),
        ),
      );
      if (mounted) {
        Navigator.pop(context, product);
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
