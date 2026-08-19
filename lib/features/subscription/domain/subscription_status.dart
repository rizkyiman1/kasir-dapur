import 'package:kasir_dapur/core/errors/app_exception.dart';

enum SubscriptionStatus {
  active,
  pending,
  expired,
  cancelled,
  gracePeriod;

  String get storageValue {
    return switch (this) {
      SubscriptionStatus.active => 'active',
      SubscriptionStatus.pending => 'pending',
      SubscriptionStatus.expired => 'expired',
      SubscriptionStatus.cancelled => 'cancelled',
      SubscriptionStatus.gracePeriod => 'grace_period',
    };
  }

  String get label {
    return switch (this) {
      SubscriptionStatus.active => 'Aktif',
      SubscriptionStatus.pending => 'Menunggu verifikasi',
      SubscriptionStatus.expired => 'Kedaluwarsa',
      SubscriptionStatus.cancelled => 'Dibatalkan',
      SubscriptionStatus.gracePeriod => 'Masa tenggang',
    };
  }

  /// Hanya status ini yang boleh membuka fitur berbayar.
  bool get grantsEntitlements {
    return this == SubscriptionStatus.active ||
        this == SubscriptionStatus.gracePeriod;
  }

  static const String entitledSql = "'active', 'grace_period'";

  static SubscriptionStatus parse(String value) {
    return switch (value) {
      'active' => SubscriptionStatus.active,
      'pending' => SubscriptionStatus.pending,
      'expired' => SubscriptionStatus.expired,
      'cancelled' => SubscriptionStatus.cancelled,
      'grace_period' => SubscriptionStatus.gracePeriod,
      'replaced' => SubscriptionStatus.cancelled,
      _ => throw ValidationException('Status langganan tidak dikenal: $value'),
    };
  }
}
