import 'package:kasir_dapur/database/app_database.dart';
import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/subscription/domain/billing_plan.dart';
import 'package:kasir_dapur/features/subscription/domain/entitlement_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_history_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/payment_status.dart';
import 'package:kasir_dapur/features/subscription/domain/plan.dart';
import 'package:kasir_dapur/features/subscription/domain/plan_catalog.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_config.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_payment.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_repository.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_status.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

final class SqliteSubscriptionRepository
    implements
        SubscriptionRepository,
        EntitlementRepository,
        PaymentHistoryRepository {
  SqliteSubscriptionRepository({
    required this._database,
    required this._clock,
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final AppDatabase _database;
  final ClockService _clock;
  final Uuid _uuid;

  static const String _entitledWhere =
      'business_id = ? AND status IN (${SubscriptionStatus.entitledSql})';

  @override
  Future<Subscription> upsertPlan({
    required String businessId,
    required Plan plan,
    required String source,
    required int startsAt,
    int? endsAt,
    BillingPlan? planCode,
    SubscriptionStatus status = SubscriptionStatus.active,
    int? graceEndsAt,
    String? provider,
    String? providerOrderId,
    int? verifiedAt,
    bool seedEntitlements = true,
    bool supersedeCurrent = true,
  }) {
    final BillingPlan code = planCode ?? BillingPlan.fromFamily(plan);
    return _database.runInTransaction((Transaction txn) async {
      final int now = _clock.nowEpochMs();
      if (supersedeCurrent && status.grantsEntitlements) {
        await txn.update(
          DatabaseConstants.tableSubscriptions,
          <String, Object>{
            'status': SubscriptionStatus.cancelled.storageValue,
            'updated_at': now,
          },
          where: _entitledWhere,
          whereArgs: <Object>[businessId],
        );
      }
      final String id = _uuid.v4();
      await txn.insert(DatabaseConstants.tableSubscriptions, <String, Object?>{
        'id': id,
        'business_id': businessId,
        'plan': plan.storageValue,
        'plan_code': code.storageValue,
        'status': status.storageValue,
        'source': source,
        'starts_at': startsAt,
        'ends_at': endsAt,
        'grace_ends_at': graceEndsAt,
        'provider': provider ?? SubscriptionConfig.providerDefault,
        'provider_order_id': providerOrderId,
        'verified_at': verifiedAt,
        'last_synced_at': verifiedAt,
        'created_at': now,
        'updated_at': now,
      });
      if (seedEntitlements && status.grantsEntitlements) {
        await _seedEntitlements(
          txn,
          businessId: businessId,
          subscriptionId: id,
          plan: plan,
          now: now,
        );
      }
      return Subscription(
        id: id,
        businessId: businessId,
        plan: plan,
        planCode: code,
        status: status,
        source: source,
        startsAt: startsAt,
        endsAt: endsAt,
        graceEndsAt: graceEndsAt,
        provider: provider ?? SubscriptionConfig.providerDefault,
        providerOrderId: providerOrderId,
        verifiedAt: verifiedAt,
        lastSyncedAt: verifiedAt,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  @override
  Future<Subscription?> current(String businessId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSubscriptions,
      where: _entitledWhere,
      whereArgs: <Object>[businessId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapSubscription(rows.first);
  }

  @override
  Future<Subscription?> latestPending(String businessId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSubscriptions,
      where: 'business_id = ? AND status = ?',
      whereArgs: <Object>[businessId, SubscriptionStatus.pending.storageValue],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapSubscription(rows.first);
  }

  @override
  Future<List<Subscription>> listSubscriptions(String businessId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSubscriptions,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapSubscription).toList();
  }

  @override
  Future<void> updateStatus({
    required String id,
    required SubscriptionStatus status,
    int? graceEndsAt,
    int? lastSyncedAt,
  }) async {
    final int now = _clock.nowEpochMs();
    final Map<String, Object?> values = <String, Object?>{
      'status': status.storageValue,
      'updated_at': now,
    };
    if (graceEndsAt != null) {
      values['grace_ends_at'] = graceEndsAt;
    }
    if (lastSyncedAt != null) {
      values['last_synced_at'] = lastSyncedAt;
    }
    await (await _database.database).update(
      DatabaseConstants.tableSubscriptions,
      values,
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  @override
  Future<void> replaceEntitlements({
    required String businessId,
    required String subscriptionId,
    required Plan plan,
  }) {
    return _database.runInTransaction((Transaction txn) {
      return _seedEntitlements(
        txn,
        businessId: businessId,
        subscriptionId: subscriptionId,
        plan: plan,
        now: _clock.nowEpochMs(),
      );
    });
  }

  @override
  Future<List<Entitlement>> list(String businessId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableEntitlements,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
    );
    return rows.map(_mapEntitlement).toList();
  }

  @override
  Future<Entitlement?> find({
    required String businessId,
    required FeatureKey key,
  }) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableEntitlements,
      where: 'business_id = ? AND feature_key = ?',
      whereArgs: <Object>[businessId, key.storageValue],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapEntitlement(rows.first);
  }

  @override
  Future<SubscriptionPayment> insertPayment({
    required String businessId,
    String? subscriptionId,
    required BillingPlan planCode,
    required int amountRupiah,
    required String currency,
    required PaymentStatus status,
    required String provider,
    required String clientUuid,
    String? providerOrderId,
    String? snapToken,
    String? snapRedirectUrl,
    String? failureReason,
  }) async {
    final int now = _clock.nowEpochMs();
    final String id = _uuid.v4();
    await (await _database.database).insert(
      DatabaseConstants.tableSubscriptionPayments,
      <String, Object?>{
        'id': id,
        'business_id': businessId,
        'subscription_id': subscriptionId,
        'plan_code': planCode.storageValue,
        'amount': amountRupiah,
        'currency': currency,
        'status': status.storageValue,
        'provider': provider,
        'client_uuid': clientUuid,
        'provider_order_id': providerOrderId,
        'snap_token': snapToken,
        'snap_redirect_url': snapRedirectUrl,
        'failure_reason': failureReason,
        'created_at': now,
        'updated_at': now,
      },
    );
    return SubscriptionPayment(
      id: id,
      businessId: businessId,
      subscriptionId: subscriptionId,
      planCode: planCode,
      amountRupiah: amountRupiah,
      currency: currency,
      status: status,
      provider: provider,
      clientUuid: clientUuid,
      providerOrderId: providerOrderId,
      snapToken: snapToken,
      snapRedirectUrl: snapRedirectUrl,
      failureReason: failureReason,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<List<SubscriptionPayment>> listPayments(String businessId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSubscriptionPayments,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
      orderBy: 'created_at DESC',
    );
    return rows.map(_mapPayment).toList();
  }

  @override
  Future<SubscriptionPayment?> findPaymentByClientUuid(
    String clientUuid,
  ) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSubscriptionPayments,
      where: 'client_uuid = ?',
      whereArgs: <Object>[clientUuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapPayment(rows.first);
  }

  @override
  Future<SubscriptionPayment?> findPaymentByOrderId(String orderId) async {
    final rows = await (await _database.database).query(
      DatabaseConstants.tableSubscriptionPayments,
      where: 'provider_order_id = ?',
      whereArgs: <Object>[orderId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _mapPayment(rows.first);
  }

  @override
  Future<SubscriptionPayment> updatePayment({
    required String id,
    PaymentStatus? status,
    String? subscriptionId,
    String? providerOrderId,
    String? snapToken,
    String? snapRedirectUrl,
    int? verifiedAt,
    String? failureReason,
  }) async {
    final int now = _clock.nowEpochMs();
    final Map<String, Object?> values = <String, Object?>{'updated_at': now};
    if (status != null) {
      values['status'] = status.storageValue;
    }
    if (subscriptionId != null) {
      values['subscription_id'] = subscriptionId;
    }
    if (providerOrderId != null) {
      values['provider_order_id'] = providerOrderId;
    }
    if (snapToken != null) {
      values['snap_token'] = snapToken;
    }
    if (snapRedirectUrl != null) {
      values['snap_redirect_url'] = snapRedirectUrl;
    }
    if (verifiedAt != null) {
      values['verified_at'] = verifiedAt;
    }
    if (failureReason != null) {
      values['failure_reason'] = failureReason;
    }
    final Database db = await _database.database;
    await db.update(
      DatabaseConstants.tableSubscriptionPayments,
      values,
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    final rows = await db.query(
      DatabaseConstants.tableSubscriptionPayments,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    return _mapPayment(rows.first);
  }

  Future<void> _seedEntitlements(
    Transaction txn, {
    required String businessId,
    required String subscriptionId,
    required Plan plan,
    required int now,
  }) async {
    await txn.delete(
      DatabaseConstants.tableEntitlements,
      where: 'business_id = ?',
      whereArgs: <Object>[businessId],
    );
    for (final FeatureKey key in FeatureKey.values) {
      final FeatureGrant grant = PlanCatalog.grant(plan, key);
      await txn.insert(DatabaseConstants.tableEntitlements, <String, Object>{
        'id': _uuid.v4(),
        'business_id': businessId,
        'subscription_id': subscriptionId,
        'feature_key': key.storageValue,
        'is_enabled': grant.enabled ? 1 : 0,
        'limit_value': grant.limit,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Subscription _mapSubscription(Map<String, Object?> row) {
    final Plan family = Plan.parse(readString(row['plan'], field: 'plan'));
    final String? rawCode = readStringOrNull(row['plan_code']);
    return Subscription(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      plan: family,
      planCode: (rawCode == null || rawCode.isEmpty)
          ? BillingPlan.fromFamily(family)
          : BillingPlan.parse(rawCode),
      status: SubscriptionStatus.parse(
        readString(row['status'], field: 'status'),
      ),
      source: readString(row['source'], field: 'source'),
      startsAt: readInt(row['starts_at'], field: 'starts_at'),
      endsAt: readIntOrNull(row['ends_at']),
      graceEndsAt: readIntOrNull(row['grace_ends_at']),
      provider: readStringOrNull(row['provider']),
      providerOrderId: readStringOrNull(row['provider_order_id']),
      verifiedAt: readIntOrNull(row['verified_at']),
      lastSyncedAt: readIntOrNull(row['last_synced_at']),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }

  Entitlement _mapEntitlement(Map<String, Object?> row) {
    return Entitlement(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      subscriptionId: readStringOrNull(row['subscription_id']),
      featureKey: readString(row['feature_key'], field: 'feature_key'),
      isEnabled: readBoolInt(row['is_enabled'], field: 'is_enabled'),
      limitValue: readInt(row['limit_value'], field: 'limit_value'),
    );
  }

  SubscriptionPayment _mapPayment(Map<String, Object?> row) {
    return SubscriptionPayment(
      id: readString(row['id'], field: 'id'),
      businessId: readString(row['business_id'], field: 'business_id'),
      subscriptionId: readStringOrNull(row['subscription_id']),
      planCode: BillingPlan.parse(
        readString(row['plan_code'], field: 'plan_code'),
      ),
      amountRupiah: readMoney(row['amount'], field: 'amount'),
      currency: readString(row['currency'], field: 'currency'),
      status: PaymentStatus.parse(readString(row['status'], field: 'status')),
      provider: readString(row['provider'], field: 'provider'),
      clientUuid: readString(row['client_uuid'], field: 'client_uuid'),
      providerOrderId: readStringOrNull(row['provider_order_id']),
      snapToken: readStringOrNull(row['snap_token']),
      snapRedirectUrl: readStringOrNull(row['snap_redirect_url']),
      verifiedAt: readIntOrNull(row['verified_at']),
      failureReason: readStringOrNull(row['failure_reason']),
      createdAt: readInt(row['created_at'], field: 'created_at'),
      updatedAt: readInt(row['updated_at'], field: 'updated_at'),
    );
  }
}
