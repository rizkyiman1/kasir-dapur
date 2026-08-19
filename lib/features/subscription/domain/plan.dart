import 'package:kasir_dapur/core/errors/app_exception.dart';

enum Plan {
  free,
  pro,
  business;

  String get storageValue => name;

  String get label {
    return switch (this) {
      Plan.free => 'Free',
      Plan.pro => 'Pro',
      Plan.business => 'Business',
    };
  }

  String get summary {
    return switch (this) {
      Plan.free => 'Satu usaha, kasir offline, inventori dasar, laporan harian, barcode, dan struk dasar.',
      Plan.pro => 'Produk tak terbatas, beberapa kasir, laporan lanjutan, ekspor, pelanggan, pengeluaran, dan cadangan cloud.',
      Plan.business => 'Seluruh fitur Pro dengan sinkronisasi cloud dan cadangan lanjutan yang sudah operasional.',
    };
  }

  int get rank {
    return switch (this) {
      Plan.free => 0,
      Plan.pro => 1,
      Plan.business => 2,
    };
  }

  bool includes(Plan other) => rank >= other.rank;

  static Plan parse(String value) {
    return switch (value) {
      'free' => Plan.free,
      'pro' => Plan.pro,
      'business' => Plan.business,
      _ => throw ValidationException('Paket tidak dikenal: $value'),
    };
  }
}
