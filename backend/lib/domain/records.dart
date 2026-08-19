import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/domain/status.dart';

final class PaymentRecord {
  PaymentRecord({
    required this.id,
    required this.businessId,
    required this.planCode,
    required this.amountRupiah,
    required this.currency,
    required this.clientUuid,
    required this.orderId,
    required this.state,
    required this.midtransStatus,
    this.snapToken,
    this.snapRedirectUrl,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final BillingPlan planCode;
  final int amountRupiah;
  final String currency;
  final String clientUuid;
  final String orderId;
  CloudPaymentState state;
  MidtransTransactionStatus midtransStatus;
  String? snapToken;
  String? snapRedirectUrl;
  int? verifiedAt;
  final int createdAt;
  int updatedAt;
}

final class SubscriptionRecord {
  SubscriptionRecord({
    required this.id,
    required this.businessId,
    required this.planCode,
    required this.status,
    required this.source,
    required this.startsAt,
    this.endsAt,
    this.graceEndsAt,
    this.orderId,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  BillingPlan planCode;
  SubscriptionStatus status;
  String source;
  int startsAt;
  int? endsAt;
  int? graceEndsAt;
  String? orderId;
  int? verifiedAt;
  final int createdAt;
  int updatedAt;
}

final class EntitlementRecord {
  const EntitlementRecord({
    required this.featureKey,
    required this.isEnabled,
    required this.limitValue,
  });

  final String featureKey;
  final bool isEnabled;
  final int limitValue;
}

final class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.at,
    required this.action,
    required this.entity,
    this.businessId,
    this.orderId,
    required this.detail,
  });

  final String id;
  final int at;
  final String action;
  final String entity;
  final String? businessId;
  final String? orderId;
  final String detail;
}

final class WebhookReceipt {
  const WebhookReceipt({
    required this.fingerprint,
    required this.orderId,
    required this.status,
    required this.receivedAt,
    required this.duplicate,
  });

  final String fingerprint;
  final String orderId;
  final String status;
  final int receivedAt;
  final bool duplicate;
}
