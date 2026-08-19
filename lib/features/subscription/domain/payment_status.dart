import 'package:kasir_dapur/core/errors/app_exception.dart';

enum PaymentStatus {
  pending,
  verified,
  failed,
  cancelled,
  expired;

  String get storageValue => name;

  String get label {
    return switch (this) {
      PaymentStatus.pending => 'Menunggu verifikasi',
      PaymentStatus.verified => 'Terverifikasi',
      PaymentStatus.failed => 'Gagal',
      PaymentStatus.cancelled => 'Dibatalkan',
      PaymentStatus.expired => 'Kedaluwarsa',
    };
  }

  static PaymentStatus parse(String value) {
    return switch (value) {
      'pending' || 'created' => PaymentStatus.pending,
      'verified' || 'paid' => PaymentStatus.verified,
      'failed' => PaymentStatus.failed,
      'cancelled' => PaymentStatus.cancelled,
      'expired' => PaymentStatus.expired,
      _ => throw ValidationException('Status pembayaran tidak dikenal: $value'),
    };
  }
}
