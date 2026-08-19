import 'package:kasir_dapur/config/brand.dart';
import 'package:kasir_dapur/features/transactions/domain/payment_method.dart';

enum ReceiptBehavior {
  ask,
  auto,
  skip;

  static ReceiptBehavior parse(String? value) {
    return switch (value) {
      'auto' => ReceiptBehavior.auto,
      'skip' => ReceiptBehavior.skip,
      _ => ReceiptBehavior.ask,
    };
  }

  String get storageValue => name;

  String get label {
    return switch (this) {
      ReceiptBehavior.ask => 'Tampilkan struk',
      ReceiptBehavior.auto => 'Ikuti cetak otomatis',
      ReceiptBehavior.skip => 'Sembunyikan struk',
    };
  }

  String get subtitle {
    return switch (this) {
      ReceiptBehavior.ask => 'Dialog struk muncul setelah pembayaran.',
      ReceiptBehavior.auto => 'Jika cetak otomatis aktif, dialog dilewati. Jika tidak, struk tetap ditampilkan.',
      ReceiptBehavior.skip => 'Dialog struk tidak muncul. Cetak otomatis tetap mengikuti pengaturan printer.',
    };
  }
}

final class StoreProfile {
  const StoreProfile({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.logoPath,
    this.receiptFooter,
    this.defaultPayment = PaymentMethod.cash,
    this.receiptBehavior = ReceiptBehavior.ask,
  });

  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? logoPath;
  final String? receiptFooter;
  final PaymentMethod defaultPayment;
  final ReceiptBehavior receiptBehavior;

  bool get hasLogo => logoPath != null && logoPath!.isNotEmpty;

  String get receiptName => name.trim().isEmpty ? Brand.appName : name.trim();
}

final class StoreProfilePatch {
  const StoreProfilePatch({
    this.name,
    this.address,
    this.phone,
    this.receiptFooter,
    this.defaultPayment,
    this.receiptBehavior,
    this.logoPath,
    this.clearLogo = false,
    this.clearAddress = false,
    this.clearPhone = false,
    this.clearFooter = false,
  });

  final String? name;
  final String? address;
  final String? phone;
  final String? receiptFooter;
  final PaymentMethod? defaultPayment;
  final ReceiptBehavior? receiptBehavior;
  final String? logoPath;
  final bool clearLogo;
  final bool clearAddress;
  final bool clearPhone;
  final bool clearFooter;
}

abstract class LogoPicker {
  Future<String?> pickImagePath();
}
