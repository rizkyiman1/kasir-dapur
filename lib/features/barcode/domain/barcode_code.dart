enum BarcodeSymbology {
  ean13,
  ean8,
  upcA,
  upcE,
  code128,
  qr,
  unknown;

  String get label {
    return switch (this) {
      BarcodeSymbology.ean13 => 'EAN-13',
      BarcodeSymbology.ean8 => 'EAN-8',
      BarcodeSymbology.upcA => 'UPC-A',
      BarcodeSymbology.upcE => 'UPC-E',
      BarcodeSymbology.code128 => 'Code 128',
      BarcodeSymbology.qr => 'QR',
      BarcodeSymbology.unknown => 'Barcode',
    };
  }

  bool get isSupported {
    return this != BarcodeSymbology.unknown;
  }

  static BarcodeSymbology detect(String raw) {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return BarcodeSymbology.unknown;
    }
    if (RegExp(r'^\d{13}$').hasMatch(trimmed)) {
      return BarcodeSymbology.ean13;
    }
    if (RegExp(r'^\d{12}$').hasMatch(trimmed)) {
      return BarcodeSymbology.upcA;
    }
    if (RegExp(r'^\d{8}$').hasMatch(trimmed)) {
      return BarcodeSymbology.ean8;
    }
    if (RegExp(r'^\d{6,7}$').hasMatch(trimmed)) {
      return BarcodeSymbology.upcE;
    }
    if (trimmed.contains('://') || trimmed.contains('\n')) {
      return BarcodeSymbology.qr;
    }
    if (RegExp(r'^[A-Za-z0-9\-\.\/\+]+$').hasMatch(trimmed)) {
      return BarcodeSymbology.code128;
    }
    return BarcodeSymbology.qr;
  }
}

final class ScannedBarcode {
  const ScannedBarcode({
    required this.raw,
    this.symbology = BarcodeSymbology.unknown,
  });

  final String raw;
  final BarcodeSymbology symbology;

  String get normalized => BarcodeNormalizer.primary(raw);
}

abstract final class BarcodeNormalizer {
  static String primary(String raw) => raw.trim();

  /// Kunci pencarian: UPC-A dan EAN-13 sering tertukar leading zero.
  static List<String> lookupKeys(String raw, {BarcodeSymbology? symbology}) {
    final String trimmed = primary(raw);
    if (trimmed.isEmpty) {
      return const [];
    }
    final Set<String> keys = <String>{trimmed};
    final String digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 6) {
      keys.add(digits);
    }
    if (digits.length == 12) {
      keys.add('0$digits');
    }
    if (digits.length == 13 && digits.startsWith('0')) {
      keys.add(digits.substring(1));
    }
    if (symbology == BarcodeSymbology.qr ||
        symbology == BarcodeSymbology.code128) {
      keys.add(trimmed);
    }
    return keys.toList();
  }
}
