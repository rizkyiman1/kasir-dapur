import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/features/barcode/domain/barcode_code.dart';
import 'package:kasir_dapur/features/barcode/domain/camera_permission.dart';
import 'package:kasir_dapur/features/barcode/presentation/barcode_cart_flow.dart';
import 'package:kasir_dapur/features/barcode/presentation/barcode_scanner_page.dart';
import 'package:kasir_dapur/widgets/kd_button.dart';
import 'package:kasir_dapur/widgets/kd_legal_footer.dart';

class BarcodePage extends ConsumerWidget {
  const BarcodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            BarcodePermissionCopy.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(BarcodePermissionCopy.explanation),
          const SizedBox(height: 8),
          const Text(
            'Format: EAN-13, EAN-8, UPC, Code 128, dan QR jika relevan.',
          ),
          const SizedBox(height: 20),
          KdButton(
            label: 'Pindai barcode',
            icon: Icons.qr_code_scanner,
            onPressed: () => unawaited(_scan(context, ref)),
          ),
          const SizedBox(height: 24),
          const KdLegalFooter(),
        ],
      ),
    );
  }

  Future<void> _scan(BuildContext context, WidgetRef ref) async {
    final ScannedBarcode? scanned = await openBarcodeScanner(context);
    if (scanned == null || !context.mounted) {
      return;
    }
    await applyScannedBarcode(
      ref: ref,
      context: context,
      raw: scanned.raw,
      symbology: scanned.symbology,
    );
  }
}
