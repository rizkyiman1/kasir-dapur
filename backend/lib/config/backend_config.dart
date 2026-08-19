import 'dart:io';

import 'package:kasir_dapur_backend/config/brand.dart';

enum MidtransEnvironment { sandbox, production }

/// Konfigurasi proses. Secret hanya dari lingkungan, bukan dari klien Flutter.
final class BackendConfig {
  const BackendConfig({
    required this.port,
    required this.publicBaseUrl,
    required this.midtrans,
    required this.pricing,
    required this.jwtSecret,
    required this.googleSheetsClientId,
    required this.googleSheetsClientSecret,
    required this.googleSheetsSpreadsheetId,
    required this.googleSheetsAccessToken,
    required this.backupBucket,
    required this.billingSqlitePath,
    required this.trustProxyHeaders,
    required this.trustedProxyIps,
    required this.enforceProductionSecrets,
  });

  final int port;
  final String publicBaseUrl;
  final MidtransConfig midtrans;
  final PricingConfig pricing;
  final String jwtSecret;
  final String googleSheetsClientId;
  final String googleSheetsClientSecret;
  final String googleSheetsSpreadsheetId;
  final String googleSheetsAccessToken;
  final String backupBucket;
  final String billingSqlitePath;
  final bool trustProxyHeaders;
  final Set<String> trustedProxyIps;
  final bool enforceProductionSecrets;

  bool get sheetsConfigured =>
      googleSheetsClientId.isNotEmpty && googleSheetsClientSecret.isNotEmpty;

  bool get sheetsPushConfigured =>
      googleSheetsSpreadsheetId.isNotEmpty &&
      googleSheetsAccessToken.isNotEmpty;

  static BackendConfig fromMap(Map<String, String> env) {
    return BackendConfig(
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      publicBaseUrl: env['PUBLIC_BASE_URL'] ?? 'http://localhost:8080',
      midtrans: MidtransConfig.fromMap(env),
      pricing: PricingConfig.fromMap(env),
      jwtSecret: env['JWT_SECRET'] ?? '',
      googleSheetsClientId: env['GOOGLE_SHEETS_CLIENT_ID'] ?? '',
      googleSheetsClientSecret: env['GOOGLE_SHEETS_CLIENT_SECRET'] ?? '',
      googleSheetsSpreadsheetId: env['GOOGLE_SHEETS_SPREADSHEET_ID'] ?? '',
      googleSheetsAccessToken: env['GOOGLE_SHEETS_ACCESS_TOKEN'] ?? '',
      backupBucket: env['BACKUP_BUCKET'] ?? '',
      billingSqlitePath:
          env['BILLING_SQLITE_PATH'] ??
          '${Directory.current.path}${Platform.pathSeparator}var${Platform.pathSeparator}billing.db',
      trustProxyHeaders: _readBool(env['TRUST_PROXY_HEADERS']),
      trustedProxyIps: _readCsvSet(env['TRUSTED_PROXY_IPS']),
      enforceProductionSecrets: _readBool(env['ENFORCE_PRODUCTION_SECRETS']),
    );
  }

  /// Ringkasan aman untuk health check. Tidak berisi Server Key.
  Map<String, Object> get publicHealth {
    return <String, Object>{
      'app': Brand.appName,
      'company': Brand.companyName,
      'midtrans_environment': midtrans.environment.name.toUpperCase(),
      'midtrans_configured': midtrans.isConfigured,
      'pricing_ready': pricing.hasAnyPaidPrice,
      'google_sheets_configured': sheetsPushConfigured || sheetsConfigured,
    };
  }

  BackendConfig copyWith({
    int? port,
    String? publicBaseUrl,
    MidtransConfig? midtrans,
    PricingConfig? pricing,
    String? jwtSecret,
    String? googleSheetsClientId,
    String? googleSheetsClientSecret,
    String? googleSheetsSpreadsheetId,
    String? googleSheetsAccessToken,
    String? backupBucket,
    String? billingSqlitePath,
    bool? trustProxyHeaders,
    Set<String>? trustedProxyIps,
    bool? enforceProductionSecrets,
  }) {
    return BackendConfig(
      port: port ?? this.port,
      publicBaseUrl: publicBaseUrl ?? this.publicBaseUrl,
      midtrans: midtrans ?? this.midtrans,
      pricing: pricing ?? this.pricing,
      jwtSecret: jwtSecret ?? this.jwtSecret,
      googleSheetsClientId: googleSheetsClientId ?? this.googleSheetsClientId,
      googleSheetsClientSecret:
          googleSheetsClientSecret ?? this.googleSheetsClientSecret,
      googleSheetsSpreadsheetId:
          googleSheetsSpreadsheetId ?? this.googleSheetsSpreadsheetId,
      googleSheetsAccessToken:
          googleSheetsAccessToken ?? this.googleSheetsAccessToken,
      backupBucket: backupBucket ?? this.backupBucket,
      billingSqlitePath: billingSqlitePath ?? this.billingSqlitePath,
      trustProxyHeaders: trustProxyHeaders ?? this.trustProxyHeaders,
      trustedProxyIps: trustedProxyIps ?? this.trustedProxyIps,
      enforceProductionSecrets:
          enforceProductionSecrets ?? this.enforceProductionSecrets,
    );
  }

  void validateProductionSecrets() {
    if (!enforceProductionSecrets) {
      return;
    }
    _requireSecret('JWT_SECRET', jwtSecret);
    _requireSecret('MIDTRANS_SERVER_KEY', midtrans.serverKey);
    _requireSecret('MIDTRANS_CLIENT_KEY', midtrans.clientKey);
    _requireSecret('MIDTRANS_MERCHANT_ID', midtrans.merchantId);
  }

  static bool _readBool(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }

  static Set<String> _readCsvSet(String? value) {
    if (value == null || value.trim().isEmpty) {
      return <String>{};
    }
    return value
        .split(',')
        .map((String item) => item.trim())
        .where((String item) => item.isNotEmpty)
        .toSet();
  }

  static void _requireSecret(String key, String value) {
    final String normalized = value.trim();
    final bool placeholder =
        normalized.isEmpty ||
        normalized.contains('<') ||
        normalized.toLowerCase().contains('change-me') ||
        normalized.toLowerCase().contains('placeholder');
    if (placeholder) {
      throw StateError(
        'Konfigurasi production tidak valid: $key belum diisi dengan secret valid.',
      );
    }
  }
}

final class MidtransConfig {
  const MidtransConfig({
    required this.environment,
    required this.serverKey,
    required this.clientKey,
    required this.merchantId,
  });

  final MidtransEnvironment environment;
  final String serverKey;
  final String clientKey;
  final String merchantId;

  bool get isConfigured =>
      serverKey.isNotEmpty && clientKey.isNotEmpty && merchantId.isNotEmpty;

  bool get isSandbox => environment == MidtransEnvironment.sandbox;

  String get snapBaseUrl {
    return isSandbox
        ? 'https://app.sandbox.midtrans.com'
        : 'https://app.midtrans.com';
  }

  String get apiBaseUrl {
    return isSandbox
        ? 'https://api.sandbox.midtrans.com'
        : 'https://api.midtrans.com';
  }

  String get snapTransactionsUrl => '$snapBaseUrl/snap/v1/transactions';

  String statusUrl(String orderId) => '$apiBaseUrl/v2/$orderId/status';

  static MidtransConfig fromMap(Map<String, String> env) {
    final String? envMode = env['MIDTRANS_ENVIRONMENT'];
    final String? legacyProdFlag = env['MIDTRANS_IS_PRODUCTION'];
    final MidtransEnvironment resolvedEnvironment;
    if (envMode != null && envMode.trim().isNotEmpty) {
      resolvedEnvironment = parseEnvironment(envMode);
    } else if (_readBool(legacyProdFlag)) {
      resolvedEnvironment = MidtransEnvironment.production;
    } else {
      resolvedEnvironment = MidtransEnvironment.sandbox;
    }
    return MidtransConfig(
      environment: resolvedEnvironment,
      serverKey: env['MIDTRANS_SERVER_KEY'] ?? '',
      clientKey: env['MIDTRANS_CLIENT_KEY'] ?? '',
      merchantId: env['MIDTRANS_MERCHANT_ID'] ?? '',
    );
  }

  static MidtransEnvironment parseEnvironment(String? value) {
    final String normalized = (value ?? 'SANDBOX').trim().toUpperCase();
    if (normalized == 'PRODUCTION' || normalized == 'PROD') {
      return MidtransEnvironment.production;
    }
    return MidtransEnvironment.sandbox;
  }

  static bool _readBool(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    return normalized == '1' || normalized == 'true' || normalized == 'yes';
  }
}

final class PricingConfig {
  const PricingConfig({
    required this.proMonthly,
    required this.proYearly,
    required this.businessMonthly,
    required this.businessYearly,
    required this.gracePeriodDays,
  });

  final int? proMonthly;
  final int? proYearly;
  final int? businessMonthly;
  final int? businessYearly;
  final int gracePeriodDays;

  bool get hasAnyPaidPrice {
    return proMonthly != null ||
        proYearly != null ||
        businessMonthly != null ||
        businessYearly != null;
  }

  static PricingConfig fromMap(Map<String, String> env) {
    return PricingConfig(
      proMonthly: _money(env['PLAN_PRICE_PRO_MONTHLY']),
      proYearly: _money(env['PLAN_PRICE_PRO_YEARLY']),
      businessMonthly: _money(env['PLAN_PRICE_BUSINESS_MONTHLY']),
      businessYearly: _money(env['PLAN_PRICE_BUSINESS_YEARLY']),
      gracePeriodDays: int.tryParse(env['PLAN_GRACE_DAYS'] ?? '') ?? 7,
    );
  }

  static int? _money(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final int? value = int.tryParse(raw.trim());
    if (value == null || value < 0) {
      throw FormatException('Harga harus integer Rupiah: $raw');
    }
    return value;
  }
}

/// Membaca .env tanpa menimpa variabel proses yang sudah ada.
Map<String, String> loadProcessEnv({Directory? directory}) {
  final Map<String, String> env = Map<String, String>.from(
    Platform.environment,
  );
  final File file = File(
    '${(directory ?? Directory.current).path}${Platform.pathSeparator}.env',
  );
  if (!file.existsSync()) {
    return env;
  }
  for (final String line in file.readAsLinesSync()) {
    final String trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    final int sep = trimmed.indexOf('=');
    if (sep <= 0) {
      continue;
    }
    final String key = trimmed.substring(0, sep).trim();
    String value = trimmed.substring(sep + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      value = value.substring(1, value.length - 1);
    }
    env.putIfAbsent(key, () => value);
  }
  return env;
}
