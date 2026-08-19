import 'package:kasir_dapur/core/errors/app_exception.dart';

enum ReceiptPaperSize {
  mm58(32, '58mm'),
  mm80(48, '80mm');

  const ReceiptPaperSize(this.columns, this.storageValue);

  final int columns;
  final String storageValue;

  String get label => storageValue;

  static ReceiptPaperSize parse(String? value) {
    return switch (value) {
      '80mm' || '80' => ReceiptPaperSize.mm80,
      '58mm' || '58' || null => ReceiptPaperSize.mm58,
      _ => throw ValidationException('Ukuran kertas tidak dikenal: $value'),
    };
  }
}
