import 'package:kasir_dapur/features/printers/domain/receipt_paper_size.dart';

final class PrinterDevice {
  const PrinterDevice({required this.name, required this.address});

  final String name;
  final String address;
}

final class PrinterProfile {
  const PrinterProfile({
    required this.id,
    required this.businessId,
    required this.paperSize,
    required this.autoPrint,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
    this.deviceName,
    this.deviceAddress,
    this.lastSaleId,
  });

  final String id;
  final String businessId;
  final ReceiptPaperSize paperSize;
  final String? deviceName;
  final String? deviceAddress;
  final bool autoPrint;
  final String? lastSaleId;
  final bool isDefault;
  final int createdAt;
  final int updatedAt;

  bool get hasDevice =>
      deviceAddress != null && deviceAddress!.trim().isNotEmpty;

  PrinterProfile copyWith({
    ReceiptPaperSize? paperSize,
    String? deviceName,
    String? deviceAddress,
    bool? autoPrint,
    String? lastSaleId,
    bool? isDefault,
    int? updatedAt,
    bool clearDevice = false,
    bool clearLastSale = false,
  }) {
    return PrinterProfile(
      id: id,
      businessId: businessId,
      paperSize: paperSize ?? this.paperSize,
      deviceName: clearDevice ? null : (deviceName ?? this.deviceName),
      deviceAddress: clearDevice ? null : (deviceAddress ?? this.deviceAddress),
      autoPrint: autoPrint ?? this.autoPrint,
      lastSaleId: clearLastSale ? null : (lastSaleId ?? this.lastSaleId),
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
