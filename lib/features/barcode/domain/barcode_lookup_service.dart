import 'package:kasir_dapur/features/barcode/domain/barcode_code.dart';
import 'package:kasir_dapur/features/products/domain/product.dart';
import 'package:kasir_dapur/features/products/domain/product_repository.dart';

final class BarcodeLookupResult {
  const BarcodeLookupResult({
    required this.scanned,
    this.product,
    this.matchedKey,
  });

  final ScannedBarcode scanned;
  final Product? product;
  final String? matchedKey;

  bool get found => product != null;

  String get displayCode => matchedKey ?? scanned.normalized;
}

final class BarcodeLookupService {
  const BarcodeLookupService({required this._products});

  final ProductRepository _products;

  Future<BarcodeLookupResult> lookup({
    required String businessId,
    required String raw,
    BarcodeSymbology? symbology,
  }) async {
    final ScannedBarcode scanned = ScannedBarcode(
      raw: raw,
      symbology: symbology ?? BarcodeSymbology.detect(raw),
    );
    final List<String> keys = BarcodeNormalizer.lookupKeys(
      raw,
      symbology: scanned.symbology,
    );
    if (keys.isEmpty) {
      return BarcodeLookupResult(scanned: scanned);
    }
    for (final String key in keys) {
      final Product? byBarcode = await _products.findByBarcode(
        businessId: businessId,
        barcode: key,
      );
      if (byBarcode != null) {
        return BarcodeLookupResult(
          scanned: scanned,
          product: byBarcode,
          matchedKey: key,
        );
      }
    }
    if (scanned.symbology == BarcodeSymbology.code128 ||
        scanned.symbology == BarcodeSymbology.qr) {
      for (final String key in keys) {
        final Product? bySku = await _products.findBySku(
          businessId: businessId,
          sku: key,
        );
        if (bySku != null) {
          return BarcodeLookupResult(
            scanned: scanned,
            product: bySku,
            matchedKey: key,
          );
        }
      }
    }
    return BarcodeLookupResult(scanned: scanned);
  }
}
