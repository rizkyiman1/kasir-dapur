/// Status transaksi Midtrans yang diterima webhook.
enum MidtransTransactionStatus {
  pending,
  settlement,
  capture,
  expire,
  cancel,
  deny,
  failure;

  String get storageValue => name;

  bool get isSuccess =>
      this == MidtransTransactionStatus.settlement ||
      this == MidtransTransactionStatus.capture;

  bool get isTerminalFailure {
    return this == MidtransTransactionStatus.expire ||
        this == MidtransTransactionStatus.cancel ||
        this == MidtransTransactionStatus.deny ||
        this == MidtransTransactionStatus.failure;
  }

  static MidtransTransactionStatus parse(String value) {
    final String normalized = value.trim().toLowerCase();
    for (final MidtransTransactionStatus status
        in MidtransTransactionStatus.values) {
      if (status.name == normalized) {
        return status;
      }
    }
    throw FormatException('Status Midtrans tidak dikenal: $value');
  }
}

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

  bool get grantsEntitlements =>
      this == SubscriptionStatus.active ||
      this == SubscriptionStatus.gracePeriod;
}

enum CloudPaymentState { pending, verified, failed, cancelled, expired }

CloudPaymentState paymentStateFromMidtrans(MidtransTransactionStatus status) {
  if (status.isSuccess) {
    return CloudPaymentState.verified;
  }
  if (status == MidtransTransactionStatus.pending) {
    return CloudPaymentState.pending;
  }
  if (status == MidtransTransactionStatus.expire) {
    return CloudPaymentState.expired;
  }
  if (status == MidtransTransactionStatus.cancel) {
    return CloudPaymentState.cancelled;
  }
  return CloudPaymentState.failed;
}
