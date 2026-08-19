import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:kasir_dapur_backend/auth/jwt_service.dart';
import 'package:kasir_dapur_backend/auth/user_store.dart';
import 'package:kasir_dapur_backend/billing/billing_state.dart';
import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/billing_plan.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/domain/status.dart';
import 'package:kasir_dapur_backend/middleware/rate_limiter.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_gateway.dart';
import 'package:kasir_dapur_backend/midtrans/midtrans_signature.dart';
import 'package:kasir_dapur_backend/runtime.dart';
import 'package:shelf/shelf.dart';

const String testServerKey = 'test-midtrans-server-key';
const String testJwtSecret = 'test-jwt-secret-min-32-characters-ok';

BackendConfig testConfig({String serverKey = testServerKey}) {
  return BackendConfig(
    port: 0,
    publicBaseUrl: 'http://localhost',
    midtrans: MidtransConfig(
      environment: MidtransEnvironment.sandbox,
      serverKey: serverKey,
      clientKey: 'test-client-key',
      merchantId: 'G123',
    ),
    pricing: const PricingConfig(
      proMonthly: 150000,
      proYearly: 1500000,
      businessMonthly: 350000,
      businessYearly: 3500000,
      gracePeriodDays: 7,
    ),
    jwtSecret: testJwtSecret,
    googleSheetsClientId: '',
    googleSheetsClientSecret: '',
    googleSheetsSpreadsheetId: '',
    googleSheetsAccessToken: '',
    backupBucket: '',
    billingSqlitePath:
        '${Directory.systemTemp.path}${Platform.pathSeparator}kasir-dapur-backend-test-${DateTime.now().microsecondsSinceEpoch}.db',
    trustProxyHeaders: false,
    trustedProxyIps: const <String>{},
    enforceProductionSecrets: false,
  );
}

/// Buat runtime test dengan user tertentu sudah terdaftar.
/// Secara default mendaftarkan dua bisnis: biz-A dan biz-B.
BackendRuntime testRuntime({
  MidtransGateway? midtrans,
  AppStore? store,
  UserStore? userStore,
  BackendConfig? config,
  BillingFaultHooks? billingFaultHooks,
}) {
  final UserStore us = userStore ?? _defaultUserStore();
  final JwtService jwt = JwtService(secret: testJwtSecret);
  final BackendConfig resolvedConfig = config ?? testConfig();
  return BackendRuntime.testing(
    config: resolvedConfig,
    midtrans: midtrans ?? FakeMidtransGateway(),
    store: store,
    userStore: us,
    jwtService: jwt,
    // Matikan rate limiter di test agar tidak mengganggu
    rateLimiter: RateLimiter(
      rules: <String, RateLimitRule>{
        '/': RateLimitRule(maxRequests: 10000, window: Duration(hours: 1)),
      },
    ),
    billingFaultHooks: billingFaultHooks,
  );
}

UserStore _defaultUserStore() {
  final UserStore us = UserStore();
  us.register(
    id: 'user-A',
    businessId: 'biz-A',
    role: 'owner',
    pin: '1234',
    salt: 'salt-A',
  );
  us.register(
    id: 'user-B',
    businessId: 'biz-B',
    role: 'owner',
    pin: '5678',
    salt: 'salt-B',
  );
  return us;
}

/// Hasilkan Bearer token untuk user tertentu dalam test.
String tokenFor({
  required String userId,
  required String businessId,
  String role = 'owner',
  Duration expiry = JwtService.defaultExpiry,
}) {
  return JwtService(secret: testJwtSecret)
      .sign(sub: userId, businessId: businessId, role: role, expiry: expiry);
}

/// Token yang sudah expired (untuk test reject).
String expiredToken({required String userId, required String businessId}) {
  return tokenFor(
    userId: userId,
    businessId: businessId,
    expiry: Duration(seconds: -1),
  );
}

/// Token dengan secret salah (untuk test reject).
String tamperedToken({required String userId, required String businessId}) {
  return JwtService(secret: 'wrong-secret-totally-different-key')
      .sign(sub: userId, businessId: businessId, role: 'owner');
}

String wrongIssuerToken({required String userId, required String businessId}) {
  final int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final JWT jwt = JWT(<String, Object>{
    'sub': userId,
    'business_id': businessId,
    'role': 'owner',
    'iat': now,
    'exp': now + JwtService.defaultExpiry.inSeconds,
  }, issuer: 'not-kasir-dapur');
  return jwt.sign(SecretKey(testJwtSecret), algorithm: JWTAlgorithm.HS256);
}

Map<String, Object> signedNotification({
  required String orderId,
  required String status,
  required int amountRupiah,
  String statusCode = '200',
  String transactionId = 'trx-1',
  String merchantId = 'G123',
  String serverKey = testServerKey,
}) {
  final String gross = MidtransSignature.grossAmountOf(amountRupiah);
  return <String, Object>{
    'order_id': orderId,
    'status_code': statusCode,
    'gross_amount': gross,
    'transaction_status': status,
    'transaction_id': transactionId,
    'merchant_id': merchantId,
    'signature_key': MidtransSignature.digest(
      orderId: orderId,
      statusCode: statusCode,
      grossAmount: gross,
      serverKey: serverKey,
    ),
    'payment_type': 'bank_transfer',
    'currency': 'IDR',
  };
}

Future<Response> postJson(
  Handler handler,
  String path,
  Map<String, Object?> body, {
  String? token,
}) async {
  return await handler(
    Request(
      'POST',
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: <String, String>{
        'content-type': 'application/json',
        if (token != null) 'authorization': 'Bearer $token',
      },
    ),
  );
}

Future<Response> getJson(Handler handler, String path, {String? token}) async {
  return await handler(
    Request(
      'GET',
      Uri.parse('http://localhost$path'),
      headers: <String, String>{
        if (token != null) 'authorization': 'Bearer $token',
      },
    ),
  );
}

Future<Map<String, Object?>> readBody(Response response) async {
  final Object decoded = jsonDecode(await response.readAsString()) as Object;
  return (decoded as Map).map(
    (Object? key, Object? value) =>
        MapEntry<String, Object?>(key.toString(), value),
  );
}

void seedActivePlan({
  required BackendRuntime runtime,
  required String businessId,
  required BillingPlan plan,
}) {
  if (plan == BillingPlan.free) {
    runtime.billing.ensureFree(businessId: businessId);
    return;
  }
  final int now = runtime.store.clock.nowEpochMs();
  final PaymentRecord payment = PaymentRecord(
    id: runtime.store.nextId(),
    businessId: businessId,
    planCode: plan,
    amountRupiah: runtime.catalog.requireAmount(plan),
    currency: 'IDR',
    clientUuid: 'seed-$businessId-${plan.storageValue}',
    orderId: 'SEED-$businessId-${plan.storageValue}-${runtime.store.nextId()}',
    state: CloudPaymentState.pending,
    midtransStatus: MidtransTransactionStatus.pending,
    createdAt: now,
    updatedAt: now,
  );
  runtime.billing.db.transaction<void>((_) {
    runtime.billing.payments.create(payment);
    runtime.billing.activatePaid(
      payment: payment,
      catalog: runtime.catalog,
      verifiedAt: now,
    );
  });
}
