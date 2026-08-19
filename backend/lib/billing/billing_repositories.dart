import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/domain/status.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

final class PaymentRepository {
  PaymentRepository(this._db);
  final Database _db;

  PaymentRecord? findByOrderId(String orderId) {
    final ResultSet rs = _db.select(
      'SELECT * FROM payments WHERE order_id = ? LIMIT 1;',
      <Object?>[orderId],
    );
    if (rs.isEmpty) {
      return null;
    }
    return _rowToPayment(rs.first);
  }

  PaymentRecord? findByClientUuid(String clientUuid) {
    final ResultSet rs = _db.select(
      'SELECT * FROM payments WHERE client_uuid = ? LIMIT 1;',
      <Object?>[clientUuid],
    );
    if (rs.isEmpty) {
      return null;
    }
    return _rowToPayment(rs.first);
  }

  List<PaymentRecord> listPending() {
    final ResultSet rs = _db.select(
      "SELECT * FROM payments WHERE state = 'pending' ORDER BY updated_at ASC;",
    );
    return rs.map(_rowToPayment).toList();
  }

  List<PaymentRecord> listByBusiness(String businessId) {
    final ResultSet rs = _db.select(
      'SELECT * FROM payments WHERE business_id = ? ORDER BY created_at DESC;',
      <Object?>[businessId],
    );
    return rs.map(_rowToPayment).toList();
  }

  void create(PaymentRecord payment) {
    _db.execute(
      '''
      INSERT INTO payments (
        id, order_id, business_id, client_uuid, plan_code, amount, currency,
        provider, provider_transaction_id, state, midtrans_status,
        snap_token, snap_redirect_url, created_at, updated_at, verified_at, failure_reason
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
      ''',
      <Object?>[
        payment.id,
        payment.orderId,
        payment.businessId,
        payment.clientUuid,
        payment.planCode.storageValue,
        payment.amountRupiah,
        payment.currency,
        'midtrans',
        null,
        payment.state.name,
        payment.midtransStatus.storageValue,
        payment.snapToken,
        payment.snapRedirectUrl,
        payment.createdAt,
        payment.updatedAt,
        payment.verifiedAt,
        null,
      ],
    );
  }

  void updateSnap({
    required String orderId,
    required String snapToken,
    required String snapRedirectUrl,
    required int updatedAt,
  }) {
    _db.execute(
      '''
      UPDATE payments
      SET snap_token = ?, snap_redirect_url = ?, updated_at = ?
      WHERE order_id = ?;
      ''',
      <Object?>[snapToken, snapRedirectUrl, updatedAt, orderId],
    );
  }

  void update(PaymentRecord payment, {String? failureReason}) {
    _db.execute(
      '''
      UPDATE payments
      SET state = ?, midtrans_status = ?, updated_at = ?, verified_at = ?,
          provider_transaction_id = ?, failure_reason = ?
      WHERE order_id = ?;
      ''',
      <Object?>[
        payment.state.name,
        payment.midtransStatus.storageValue,
        payment.updatedAt,
        payment.verifiedAt,
        null,
        failureReason,
        payment.orderId,
      ],
    );
  }

  PaymentRecord _rowToPayment(Row row) {
    return PaymentRecord(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      planCode: BillingPlan.parse(row['plan_code'] as String),
      amountRupiah: row['amount'] as int,
      currency: row['currency'] as String,
      clientUuid: row['client_uuid'] as String,
      orderId: row['order_id'] as String,
      state: CloudPaymentState.values.byName(row['state'] as String),
      midtransStatus: MidtransTransactionStatus.parse(
        row['midtrans_status'] as String,
      ),
      snapToken: row['snap_token'] as String?,
      snapRedirectUrl: row['snap_redirect_url'] as String?,
      verifiedAt: row['verified_at'] as int?,
      createdAt: row['created_at'] as int,
      updatedAt: row['updated_at'] as int,
    );
  }
}

final class SubscriptionRepository {
  SubscriptionRepository(this._db);
  final Database _db;

  SubscriptionRecord? findCurrentByBusiness(String businessId) {
    final ResultSet rs = _db.select(
      '''
      SELECT * FROM subscriptions
      WHERE business_id = ?
      ORDER BY updated_at DESC
      LIMIT 1;
      ''',
      <Object?>[businessId],
    );
    if (rs.isEmpty) {
      return null;
    }
    return _rowToSubscription(rs.first);
  }

  List<SubscriptionRecord> listActive() {
    final ResultSet rs = _db.select(
      "SELECT * FROM subscriptions WHERE status IN ('active', 'grace_period');",
    );
    return rs.map(_rowToSubscription).toList();
  }

  void upsert(SubscriptionRecord row, {String? subscriptionId}) {
    final String subId = subscriptionId ?? row.id;
    _db.execute(
      '''
      INSERT INTO subscriptions (
        id, subscription_id, business_id, plan_code, status,
        starts_at, ends_at, grace_ends_at, order_id, verified_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(subscription_id) DO UPDATE SET
        plan_code = excluded.plan_code,
        status = excluded.status,
        starts_at = excluded.starts_at,
        ends_at = excluded.ends_at,
        grace_ends_at = excluded.grace_ends_at,
        order_id = excluded.order_id,
        verified_at = excluded.verified_at,
        updated_at = excluded.updated_at;
      ''',
      <Object?>[
        row.id,
        subId,
        row.businessId,
        row.planCode.storageValue,
        row.status.storageValue,
        row.startsAt,
        row.endsAt,
        row.graceEndsAt,
        row.orderId,
        row.verifiedAt,
        row.createdAt,
        row.updatedAt,
      ],
    );
  }

  SubscriptionRecord _rowToSubscription(Row row) {
    final String status = row['status'] as String;
    return SubscriptionRecord(
      id: row['id'] as String,
      businessId: row['business_id'] as String,
      planCode: BillingPlan.parse(row['plan_code'] as String),
      status: switch (status) {
        'active' => SubscriptionStatus.active,
        'pending' => SubscriptionStatus.pending,
        'expired' => SubscriptionStatus.expired,
        'cancelled' => SubscriptionStatus.cancelled,
        'grace_period' => SubscriptionStatus.gracePeriod,
        _ => SubscriptionStatus.expired,
      },
      source: 'backend',
      startsAt: row['starts_at'] as int,
      endsAt: row['ends_at'] as int?,
      graceEndsAt: row['grace_ends_at'] as int?,
      orderId: row['order_id'] as String?,
      verifiedAt: row['verified_at'] as int?,
      createdAt: row['created_at'] as int,
      updatedAt: row['updated_at'] as int,
    );
  }
}

final class EntitlementRepository {
  EntitlementRepository(this._db);
  final Database _db;

  List<EntitlementRecord> getByBusiness(String businessId) {
    final ResultSet rs = _db.select(
      'SELECT * FROM entitlements WHERE business_id = ? ORDER BY feature_key ASC;',
      <Object?>[businessId],
    );
    return rs
        .map(
          (Row row) => EntitlementRecord(
            featureKey: row['feature_key'] as String,
            isEnabled: (row['is_enabled'] as int) == 1,
            limitValue: row['limit_value'] as int,
          ),
        )
        .toList();
  }

  void replaceForBusiness({
    required String businessId,
    required BillingPlan planCode,
    required List<EntitlementRecord> rows,
    int? effectiveUntil,
    String? orderId,
  }) {
    _db.execute('DELETE FROM entitlements WHERE business_id = ?;', <Object?>[
      businessId,
    ]);
    final int now = DateTime.now().millisecondsSinceEpoch;
    for (final EntitlementRecord row in rows) {
      _db.execute(
        '''
        INSERT INTO entitlements (
          id, business_id, feature_key, plan_code, is_enabled, limit_value,
          effective_until, order_id, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        ''',
        <Object?>[
          const Uuid().v4(),
          businessId,
          row.featureKey,
          planCode.storageValue,
          row.isEnabled ? 1 : 0,
          row.limitValue,
          effectiveUntil,
          orderId,
          now,
          now,
        ],
      );
    }
  }
}

final class WebhookRepository {
  WebhookRepository(this._db);
  final Database _db;

  bool hasProcessedFingerprint(String fingerprint) {
    final ResultSet rs = _db.select(
      'SELECT 1 FROM webhook_events WHERE fingerprint = ? LIMIT 1;',
      <Object?>[fingerprint],
    );
    return rs.isNotEmpty;
  }

  bool tryClaimFingerprint({
    required String id,
    required String fingerprint,
    required String orderId,
    required int processedAt,
    required String providerStatus,
  }) {
    _db.execute(
      '''
      INSERT INTO webhook_events (
        id, fingerprint, order_id, processed_at, result_status, provider_status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(fingerprint) DO NOTHING;
      ''',
      <Object?>[
        id,
        fingerprint,
        orderId,
        processedAt,
        'processing',
        providerStatus,
        processedAt,
      ],
    );
    final ResultSet rs = _db.select(
      'SELECT id FROM webhook_events WHERE fingerprint = ? LIMIT 1;',
      <Object?>[fingerprint],
    );
    if (rs.isEmpty) {
      return false;
    }
    return (rs.first['id'] as String) == id;
  }

  void recordProcessed({
    required String id,
    required String fingerprint,
    required String orderId,
    required int processedAt,
    required String resultStatus,
    required String providerStatus,
  }) {
    _db.execute(
      '''
      INSERT INTO webhook_events (
        id, fingerprint, order_id, processed_at, result_status, provider_status, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(fingerprint) DO UPDATE SET
        processed_at = excluded.processed_at,
        result_status = excluded.result_status,
        provider_status = excluded.provider_status;
      ''',
      <Object?>[
        id,
        fingerprint,
        orderId,
        processedAt,
        resultStatus,
        providerStatus,
        processedAt,
      ],
    );
  }
}

final class BillingAuditRepository {
  BillingAuditRepository(this._db);
  final Database _db;

  void append({
    required String id,
    required String eventType,
    String? businessId,
    String? orderId,
    required String detail,
    required int createdAt,
  }) {
    _db.execute(
      '''
      INSERT INTO billing_audit_events (
        id, event_type, business_id, order_id, detail, created_at
      ) VALUES (?, ?, ?, ?, ?, ?);
      ''',
      <Object?>[id, eventType, businessId, orderId, detail, createdAt],
    );
  }
}
