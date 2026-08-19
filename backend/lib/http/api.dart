import 'dart:convert';
import 'dart:io';

import 'package:kasir_dapur_backend/auth/auth_middleware.dart';
import 'package:kasir_dapur_backend/auth/jwt_service.dart';
import 'package:kasir_dapur_backend/auth/user_store.dart';
import 'package:kasir_dapur_backend/billing/billing_state.dart';
import 'package:kasir_dapur_backend/backup/stored_backup.dart';
import 'package:kasir_dapur_backend/config/backend_config.dart';
import 'package:kasir_dapur_backend/config/brand.dart';
import 'package:kasir_dapur_backend/data/app_store.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/middleware/rate_limiter.dart';
import 'package:kasir_dapur_backend/middleware/request_size.dart';
import 'package:kasir_dapur_backend/services/checkout_service.dart';
import 'package:kasir_dapur_backend/services/webhook_service.dart';
import 'package:kasir_dapur_backend/sync/sheets_mirror.dart';
import 'package:kasir_dapur_backend/sync/sync_ingest.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';
import 'package:shelf_router/shelf_router.dart';

final class BackendApp {
  BackendApp({
    required this.config,
    required this.store,
    required this.userStore,
    required this.jwtService,
    required this.checkout,
    required this.webhook,
    required this.sync,
    required this.rateLimiter,
    required this.billing,
  });

  final BackendConfig config;
  final AppStore store;
  final UserStore userStore;
  final JwtService jwtService;
  final CheckoutService checkout;
  final WebhookService webhook;
  final SyncIngestService sync;
  final RateLimiter rateLimiter;
  final BillingState billing;

  static const String _featureCloudBackup = 'cloud_backup';
  static const String _featureAdvancedBackup = 'advanced_backup';
  static const String _featureGoogleSheets = 'google_sheets';
  static const String _featureCloudSync = 'cloud_sync';

  Handler get handler {
    final Router router = Router()
      ..get('/health', _health)
      ..post('/v1/auth/cloud/session', _cloudSession)
      ..post('/v1/billing/checkout', _checkout)
      ..get('/v1/billing/subscription', _subscription)
      ..get('/v1/billing/payments', _payments)
      ..post('/v1/billing/midtrans/notification', _midtransWebhook)
      ..post('/v1/sync/push', _syncPush)
      ..get('/v1/sync/pull', _syncPull)
      ..get('/v1/sheets/tabs', _sheetsTabs)
      ..post('/v1/sheets/export', _sheetsExport)
      ..post('/v1/backup', _backupCreate)
      ..get('/v1/backup', _backupList)
      ..get('/v1/backup/<id>', _backupGet)
      ..get('/v1/business/devices', _devicesList)
      ..post('/v1/business/devices', _devicesRegister)
      ..post('/v1/business/devices/<id>/revoke', _devicesRevoke)
      ..get('/v1/business/branches', _branchesList)
      ..post('/v1/business/branches', _branchesCreate)
      ..post('/v1/business/branches/<id>/deactivate', _branchesDeactivate)
      ..get('/v1/business/users', _usersList)
      ..post('/v1/business/users/<id>/role', _usersUpdateRole)
      ..get('/v1/business/central-dashboard', _centralDashboard)
      ..get('/v1/business/advanced-report', _advancedReport)
      ..post('/v1/business/api-keys', _apiAccessComingSoon)
      ..post('/v1/business/priority-support', _prioritySupportComingSoon)
      ..get('/v1/audit', _audit);

    return Pipeline()
        .addMiddleware(_errorMiddleware())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(logRequests(logger: _safeLog))
        .addMiddleware(requestSizeMiddleware())
        .addMiddleware(rateLimiter.middleware)
        .addMiddleware(jwtAuthMiddleware(jwtService))
        .addHandler(router.call);
  }

  // ─── CORS ───────────────────────────────────────────────────────────────────

  Middleware _errorMiddleware() {
    return (Handler inner) {
      return (Request request) async {
        try {
          return await inner(request);
        } on HttpException catch (error) {
          return _json(503, <String, Object>{'error': error.message});
        } on FormatException catch (error) {
          return _json(400, <String, Object>{'error': error.message});
        } catch (error, stackTrace) {
          _safeLog(
            'Unhandled exception on ${request.method} ${request.url.path}: $error',
            true,
          );
          _safeLog('$stackTrace', true);
          return _json(500, <String, Object>{
            'error': 'INTERNAL_SERVER_ERROR',
            'message': 'Terjadi kesalahan internal.',
          });
        }
      };
    };
  }

  Middleware _corsMiddleware() {
    final List<String> allowed = <String>[
      'https://dapur-rasa.com',
      'https://www.dapur-rasa.com',
      // tambahkan subdomain resmi jika ada
    ];
    if (config.publicBaseUrl.startsWith('http://localhost')) {
      // izinkan localhost hanya di development
      allowed.add(config.publicBaseUrl);
    }

    return corsHeaders(
      headers: <String, String>{
        ACCESS_CONTROL_ALLOW_ORIGIN: allowed.join(', '),
        ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, OPTIONS',
        ACCESS_CONTROL_ALLOW_HEADERS:
            'Authorization, Content-Type, X-Requested-With',
        ACCESS_CONTROL_MAX_AGE: '86400',
      },
    );
  }

  // ─── LOGGING AMAN ───────────────────────────────────────────────────────────

  static void _safeLog(String message, bool isError) {
    final String redacted = message
        .replaceAll(
          RegExp(r'(SB-Mid-server-[^\s]+)|(Mid-server-[^\s]+)'),
          '[REDACTED]',
        )
        .replaceAll(
          RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*'),
          'Bearer [REDACTED]',
        );
    stderr.writeln(redacted);
  }

  // ─── PUBLIC ENDPOINTS ────────────────────────────────────────────────────────

  Response _health(Request request) {
    return _json(200, <String, Object>{
      'ok': true,
      'brand': Brand.appName,
      'owner': Brand.ownerName,
      'company': Brand.companyName,
      'website': Brand.websiteUrl,
      ...config.publicHealth,
    });
  }

  Future<Response> _midtransWebhook(Request request) async {
    try {
      final Map<String, Object?> body = await _readJson(request);
      final WebhookResult result = await webhook.handle(body);
      return _json(200, result.toJson());
    } on SignatureException catch (error) {
      return _json(403, <String, Object>{'error': error.message});
    } on FormatException catch (error) {
      return _json(400, <String, Object>{'error': error.message});
    }
  }

  /// POST /v1/auth/cloud/session
  /// Menerima: { user_id, pin }
  /// Mengembalikan JWT jika credential valid.
  Future<Response> _cloudSession(Request request) async {
    if (config.jwtSecret.isEmpty) {
      return _json(503, <String, Object>{
        'error': 'Autentikasi cloud belum dikonfigurasi. PIN perangkat tetap berlaku.',
      });
    }

    final Map<String, Object?> body = await _readJson(request);
    final String userId = _requiredString(
      body,
      key: 'user_id',
      maxLength: 80,
      idLike: true,
    );
    final String pin = _requiredString(body, key: 'pin', maxLength: 32);

    final ServerUser? user = userStore.findById(userId);
    if (user == null || !user.verifyPin(pin)) {
      // Respon identik untuk user tidak ditemukan vs PIN salah — cegah user enumeration
      return _json(401, <String, Object>{'error': 'Credential tidak valid.'});
    }

    final String token = jwtService.sign(
      sub: user.id,
      businessId: user.businessId,
      role: user.role,
    );

    return _json(200, <String, Object>{
      'access_token': token,
      'token_type': 'Bearer',
      'expires_in': JwtService.defaultExpiry.inSeconds,
      'user': <String, Object>{
        'id': user.id,
        'business_id': user.businessId,
        'role': user.role,
      },
    });
  }

  // ─── AUTHENTICATED ENDPOINTS ─────────────────────────────────────────────────

  Future<Response> _checkout(Request request) async {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      final Map<String, Object?> body = await _readJson(request);
      final String planCodeRaw = _requiredString(
        body,
        key: 'plan_code',
        maxLength: 64,
      );
      final String clientUuid = _requiredString(
        body,
        key: 'client_uuid',
        maxLength: 120,
        idLike: true,
      );
      // business_id SELALU dari JWT — client tidak bisa menentukan
      final CheckoutResult result = await checkout.create(
        businessId: auth.businessId,
        planCodeRaw: planCodeRaw,
        clientUuid: clientUuid,
      );
      return _json(200, result.toJson());
    } on FormatException catch (error) {
      return _json(400, <String, Object>{'error': error.message});
    } on HttpException catch (error) {
      return _json(503, <String, Object>{'error': error.message});
    }
  }

  Response _subscription(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final SubscriptionRecord current = billing.ensureFree(
      businessId: auth.businessId,
    );
    final List<EntitlementRecord> grants = billing.entitlements.getByBusiness(
      auth.businessId,
    );
    store.entitlementsByBusiness[auth.businessId] = grants;
    return _json(200, <String, Object?>{
      'plan_code': current.planCode.storageValue,
      'status': current.status.storageValue,
      'starts_at': current.startsAt,
      'ends_at': current.endsAt,
      'grace_ends_at': current.graceEndsAt,
      'verified_at': current.verifiedAt ?? current.startsAt,
      'order_id': current.orderId ?? current.id,
      'provider': current.source == 'midtrans' ? 'midtrans' : 'backend',
      'entitlements': grants
          .map(
            (EntitlementRecord row) => <String, Object>{
              'feature_key': row.featureKey,
              'is_enabled': row.isEnabled,
              'limit_value': row.limitValue,
            },
          )
          .toList(),
    });
  }

  Response _payments(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    return _json(200, <String, Object>{
      'payments': billing.payments
          .listByBusiness(auth.businessId)
          .map(
            (PaymentRecord row) => <String, Object?>{
              'order_id': row.orderId,
              'plan_code': row.planCode.storageValue,
              'amount': row.amountRupiah,
              'currency': row.currency,
              'state': row.state.name,
              'midtrans_status': row.midtransStatus.storageValue,
              'verified_at': row.verifiedAt,
              'created_at': row.createdAt,
            },
          )
          .toList(),
    });
  }

  Future<Response> _syncPush(Request request) async {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin', 'manager'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireAnyFeature(
        businessId: auth.businessId,
        keys: const <String>[_featureGoogleSheets, _featureCloudSync],
      );
      final Map<String, Object?> body = await _readJson(request);
      final Object? jobsRaw = body['jobs'];
      final List<Map<String, Object?>> jobs;
      if (jobsRaw is List) {
        jobs = jobsRaw.map(_asJobMap).toList();
      } else {
        jobs = <Map<String, Object?>>[body];
      }
      // business_id dari JWT — client tidak bisa menentukan business tujuan
      final SyncPushResult result = await sync.push(
        businessId: auth.businessId,
        jobs: jobs,
      );
      return _json(200, result.toJson());
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    } on FormatException catch (error) {
      return _json(400, <String, Object>{'error': error.message});
    }
  }

  Response _syncPull(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin', 'manager'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireAnyFeature(
        businessId: auth.businessId,
        keys: const <String>[_featureGoogleSheets, _featureCloudSync],
      );
      // business_id dari JWT — tidak ada kondisi null → semua jobs
      return _json(200, <String, Object>{
        'jobs': store.syncJobs
            .where(
              (Map<String, Object?> job) =>
                  job['business_id'] == auth.businessId,
            )
            .toList(),
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _sheetsTabs(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin', 'manager'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireAnyFeature(
        businessId: auth.businessId,
        keys: const <String>[_featureGoogleSheets, _featureCloudSync],
      );
      // business_id dari JWT — tidak pernah null
      final Map<String, Map<String, Map<String, Object?>>> tabs = store.sheets
          .snapshot(businessId: auth.businessId);
      return _json(200, <String, Object>{
        'source': 'copy',
        'note':
            'Salinan laporan/backup. SQLite tetap database transaksi utama.',
        'tabs': <String, Object>{
          for (final String name in SheetTabs.all)
            name: (tabs[name] ?? const <String, Map<String, Object?>>{}).values
                .toList(),
        },
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Future<Response> _sheetsExport(Request request) async {
    final AuthenticatedUser auth = requireAuth(request); // pastikan autentikasi
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireAnyFeature(
        businessId: auth.businessId,
        keys: const <String>[_featureCloudSync],
      );
      await _readJson(request);
      if (!config.sheetsConfigured) {
        return _json(503, <String, Object>{
          'error': 'Google Sheets belum dikonfigurasi. SQLite tetap database transaksi utama.',
        });
      }
      return _json(200, <String, Object>{
        'status': 'queued',
        'note': 'Ekspor salinan, bukan sumber kebenaran.',
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Future<Response> _backupCreate(Request request) async {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireAnyFeature(
        businessId: auth.businessId,
        keys: const <String>[_featureCloudBackup, _featureAdvancedBackup],
      );
      final Map<String, Object?> body = await _readJson(request);
      // business_id dari JWT — abaikan nilai dari body
      final String businessId = auth.businessId;
      final String clientUuid = _requiredString(
        body,
        key: 'client_uuid',
        maxLength: 120,
        idLike: true,
      );

      final StoredBackup? existing = store.backupByClientUuid(clientUuid);
      if (existing != null) {
        // Pastikan backup ini milik bisnis yang sama
        if (existing.businessId != businessId) {
          return _json(403, <String, Object>{'error': 'Akses ditolak.'});
        }
        store.writeAudit(
          action: 'backup.duplicate',
          entity: 'backup',
          businessId: businessId,
          detail:
              'Cadangan client_uuid sudah ada. SQLite tetap sumber transaksi.',
        );
        return _json(200, <String, Object?>{
          ...existing.toDetailJson(),
          'duplicate': true,
          'status': 'stored',
        });
      }

      final Map<String, Object?> snapshot = _asJobMap(body['snapshot']);
      final String? snapshotBusinessId = snapshot['business_id'] as String?;
      if (snapshotBusinessId != null &&
          snapshotBusinessId.isNotEmpty &&
          snapshotBusinessId != businessId) {
        return _json(403, <String, Object>{
          'error': 'business_id snapshot tidak sesuai sesi.',
        });
      }
      final Map<String, int> counts = _backupCounts(snapshot['tables']);
      final StoredBackup row = StoredBackup(
        id: store.nextId(),
        businessId: businessId,
        clientUuid: clientUuid,
        createdAt: store.clock.nowEpochMs(),
        snapshot: snapshot,
        counts: counts,
      );
      store.backups.add(row);
      store.writeAudit(
        action: 'backup.created',
        entity: 'backup',
        businessId: businessId,
        detail: 'Snapshot cadangan disimpan. Bukan database transaksi.',
      );
      return _json(200, <String, Object?>{
        ...row.toDetailJson(),
        'duplicate': false,
        'status': 'stored',
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _backupList(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireAnyFeature(
        businessId: auth.businessId,
        keys: const <String>[_featureCloudBackup, _featureAdvancedBackup],
      );
      // business_id dari JWT
      return _json(200, <String, Object>{
        'note': 'Cadangan cloud. SQLite tetap database transaksi utama.',
        'backups': store
            .backupsFor(auth.businessId)
            .map((StoredBackup row) => row.toListJson())
            .toList(),
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _backupGet(Request request, String id) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireAnyFeature(
        businessId: auth.businessId,
        keys: const <String>[_featureCloudBackup, _featureAdvancedBackup],
      );
      final StoredBackup? row = store.backupById(id);
      // Selalu 404 jika backup tidak ditemukan ATAU bukan milik bisnis ini
      // Tidak mengungkap apakah ID milik bisnis lain (security by design)
      if (row == null || row.businessId != auth.businessId) {
        return _json(404, <String, Object>{
          'error': 'Cadangan tidak ditemukan.',
        });
      }
      return _json(200, row.toDetailJson());
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Map<String, int> _backupCounts(Object? tables) {
    if (tables is! Map) {
      return const <String, int>{};
    }
    return tables.map((Object? key, Object? value) {
      final int n = value is List ? value.length : 0;
      return MapEntry<String, int>(key.toString(), n);
    });
  }

  Response _audit(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    // business_id dari JWT — tidak ada kondisi null → semua events
    // Owner/admin dapat membaca audit log bisnis mereka sendiri
    final Iterable<AuditEvent> rows = store.audit.where(
      (AuditEvent event) => event.businessId == auth.businessId,
    );
    return _json(200, <String, Object>{
      'events': rows
          .map(
            (AuditEvent event) => <String, Object?>{
              'id': event.id,
              'at': event.at,
              'action': event.action,
              'entity': event.entity,
              'business_id': event.businessId,
              'order_id': event.orderId,
              'detail': event.detail,
            },
          )
          .toList(),
    });
  }

  Response _devicesList(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'multi_device');
      final rows = store.devicesFor(auth.businessId);
      return _json(200, <String, Object>{
        'devices': rows
            .map(
              (RegisteredDevice row) => <String, Object>{
                'device_id': row.id,
                'business_id': row.businessId,
                'user_id': row.userId,
                'device_name': row.deviceName,
                'status': row.status,
                'created_at': row.createdAt,
                'last_seen_at': row.lastSeenAt,
              },
            )
            .toList(),
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Future<Response> _devicesRegister(Request request) async {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'multi_device');
      final body = await _readJson(request);
      final String deviceName = _requiredString(
        body,
        key: 'device_name',
        maxLength: 80,
      );
      final String userId = _optionalString(
            body,
            key: 'user_id',
            maxLength: 80,
            idLike: true,
          ) ??
          auth.userId;
      final existing = store.findDeviceByName(
        businessId: auth.businessId,
        deviceName: deviceName,
      );
      if (existing != null) {
        return _json(200, <String, Object>{
          'device_id': existing.id,
          'status': existing.status,
          'duplicate': true,
        });
      }
      final now = store.clock.nowEpochMs();
      final row = RegisteredDevice(
        id: store.nextId(),
        businessId: auth.businessId,
        userId: userId,
        deviceName: deviceName,
        status: 'active',
        createdAt: now,
        lastSeenAt: now,
      );
      store.devices.add(row);
      store.writeAudit(
        action: 'device.registered',
        entity: 'device',
        businessId: auth.businessId,
        detail: 'Perangkat ${row.deviceName} didaftarkan.',
      );
      return _json(200, <String, Object>{
        'device_id': row.id,
        'status': row.status,
        'duplicate': false,
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _devicesRevoke(Request request, String id) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'multi_device');
      final row = store.findDevice(businessId: auth.businessId, deviceId: id);
      if (row == null) {
        return _json(404, <String, Object>{
          'error': 'Perangkat tidak ditemukan.',
        });
      }
      row.status = 'revoked';
      row.lastSeenAt = store.clock.nowEpochMs();
      store.writeAudit(
        action: 'device.revoked',
        entity: 'device',
        businessId: auth.businessId,
        detail: 'Perangkat ${row.deviceName} dinonaktifkan.',
      );
      return _json(200, <String, Object>{'status': 'revoked'});
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _branchesList(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin', 'manager'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'multi_branch');
      final rows = store.branchesFor(auth.businessId);
      return _json(200, <String, Object>{
        'branches': rows
            .map(
              (BranchRecord row) => <String, Object>{
                'branch_id': row.id,
                'business_id': row.businessId,
                'name': row.name,
                'status': row.status,
                'created_at': row.createdAt,
              },
            )
            .toList(),
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Future<Response> _branchesCreate(Request request) async {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'multi_branch');
      final body = await _readJson(request);
      final String name = _requiredString(body, key: 'name', maxLength: 80);
      final row = BranchRecord(
        id: store.nextId(),
        businessId: auth.businessId,
        name: name,
        status: 'active',
        createdAt: store.clock.nowEpochMs(),
      );
      store.branches.add(row);
      store.writeAudit(
        action: 'branch.created',
        entity: 'branch',
        businessId: auth.businessId,
        detail: 'Cabang ${row.name} dibuat.',
      );
      return _json(200, <String, Object>{
        'branch_id': row.id,
        'status': row.status,
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _branchesDeactivate(Request request, String id) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'multi_branch');
      final row = store.findBranch(businessId: auth.businessId, branchId: id);
      if (row == null) {
        return _json(404, <String, Object>{'error': 'Cabang tidak ditemukan.'});
      }
      row.status = 'inactive';
      store.writeAudit(
        action: 'branch.deactivated',
        entity: 'branch',
        businessId: auth.businessId,
        detail: 'Cabang ${row.name} dinonaktifkan.',
      );
      return _json(200, <String, Object>{'status': 'inactive'});
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _usersList(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'advanced_permission');
      final rows = userStore.usersForBusiness(auth.businessId);
      return _json(200, <String, Object>{
        'users': rows
            .map(
              (ServerUser row) => <String, Object>{
                'id': row.id,
                'business_id': row.businessId,
                'role': row.role,
              },
            )
            .toList(),
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Future<Response> _usersUpdateRole(Request request, String id) async {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'advanced_permission');
      final body = await _readJson(request);
      final String role = _requiredString(body, key: 'role', maxLength: 32);
      if (!_validRole(role)) {
        return _json(400, <String, Object>{'error': 'role tidak valid.'});
      }
      if (id == auth.userId) {
        return _json(403, <String, Object>{
          'error': 'Tidak boleh mengubah role sendiri.',
        });
      }
      if (role == 'owner') {
        return _json(403, <String, Object>{
          'error': 'Role owner tidak dapat ditetapkan ulang.',
        });
      }
      final ok = userStore.updateRole(
        userId: id,
        businessId: auth.businessId,
        role: role,
      );
      if (!ok) {
        return _json(404, <String, Object>{'error': 'User tidak ditemukan.'});
      }
      store.writeAudit(
        action: 'user.role_updated',
        entity: 'user',
        businessId: auth.businessId,
        detail: 'Role user $id diubah menjadi $role.',
      );
      return _json(200, <String, Object>{'status': 'updated', 'role': role});
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _centralDashboard(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin', 'manager'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'central_dashboard');
      final int totalBranches = store.branchesFor(auth.businessId).length;
      final int totalDevices = store.devicesFor(auth.businessId).length;
      final int totalBackups = store.backupsFor(auth.businessId).length;
      final int totalPayments = billing.payments
          .listByBusiness(auth.businessId)
          .length;
      return _json(200, <String, Object>{
        'business_id': auth.businessId,
        'summary': <String, Object>{
          'branches': totalBranches,
          'devices': totalDevices,
          'backups': totalBackups,
          'payments': totalPayments,
        },
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _advancedReport(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin', 'manager'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'advanced_report');
      final rows = billing.payments.listByBusiness(auth.businessId);
      int verifiedAmount = 0;
      int pendingAmount = 0;
      for (final PaymentRecord row in rows) {
        if (row.state.name == 'verified') {
          verifiedAmount += row.amountRupiah;
        } else {
          pendingAmount += row.amountRupiah;
        }
      }
      return _json(200, <String, Object>{
        'business_id': auth.businessId,
        'payments_count': rows.length,
        'verified_amount': verifiedAmount,
        'pending_amount': pendingAmount,
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _apiAccessComingSoon(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'api');
      return _json(501, <String, Object>{
        'error': 'FEATURE_COMING_SOON',
        'feature': 'api',
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  Response _prioritySupportComingSoon(Request request) {
    final AuthenticatedUser auth = requireAuth(request);
    final Response? forbidden = _forbiddenByRole(
      auth: auth,
      allowed: const <String>{'owner', 'admin'},
    );
    if (forbidden != null) {
      return forbidden;
    }
    try {
      _requireFeature(businessId: auth.businessId, key: 'priority_support');
      return _json(501, <String, Object>{
        'error': 'FEATURE_COMING_SOON',
        'feature': 'priority_support',
      });
    } on FeatureUnavailableException catch (error) {
      return _featureUnavailable(error.featureKey);
    }
  }

  void _requireAnyFeature({
    required String businessId,
    required List<String> keys,
  }) {
    billing.ensureFree(businessId: businessId);
    final List<EntitlementRecord> grants = billing.entitlements.getByBusiness(
      businessId,
    );
    for (final String key in keys) {
      EntitlementRecord? row;
      for (final EntitlementRecord grant in grants) {
        if (grant.featureKey == key) {
          row = grant;
          break;
        }
      }
      if (row != null && row.isEnabled) {
        return;
      }
    }
    throw FeatureUnavailableException(keys.first);
  }

  Response _featureUnavailable(String featureKey) {
    return _json(403, <String, Object>{
      'error': 'FEATURE_NOT_AVAILABLE',
      'feature': featureKey,
    });
  }

  void _requireFeature({required String businessId, required String key}) {
    _requireAnyFeature(businessId: businessId, keys: <String>[key]);
  }

  Response? _forbiddenByRole({
    required AuthenticatedUser auth,
    required Set<String> allowed,
  }) {
    if (allowed.contains(auth.role)) {
      return null;
    }
    return _json(403, <String, Object>{
      'error': 'ROLE_NOT_ALLOWED',
      'role': auth.role,
    });
  }

  bool _validRole(String role) {
    return role == 'owner' ||
        role == 'admin' ||
        role == 'manager' ||
        role == 'cashier' ||
        role == 'staff';
  }
}

final class FeatureUnavailableException implements Exception {
  const FeatureUnavailableException(this.featureKey);

  final String featureKey;
}

// ─── HELPERS ─────────────────────────────────────────────────────────────────

Future<Map<String, Object?>> _readJson(Request request) async {
  final String raw = await request.readAsString();
  if (raw.trim().isEmpty) {
    return <String, Object?>{};
  }
  final Object decoded = jsonDecode(raw) as Object;
  if (decoded is! Map) {
    throw const FormatException('Body harus JSON objek.');
  }
  return decoded.map(
    (Object? key, Object? value) =>
        MapEntry<String, Object?>(key.toString(), value),
  );
}

Response _json(int status, Map<String, Object?> body) {
  return Response(
    status,
    body: jsonEncode(body),
    headers: const <String, String>{
      HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
    },
  );
}

Map<String, Object?> _asJobMap(Object? value) {
  if (value is Map) {
    return value.map(
      (Object? key, Object? val) =>
          MapEntry<String, Object?>(key.toString(), val),
    );
  }
  return <String, Object?>{};
}

String _requiredString(
  Map<String, Object?> body, {
  required String key,
  required int maxLength,
  bool idLike = false,
}) {
  final Object? raw = body[key];
  if (raw is! String) {
    throw FormatException('$key wajib berupa string.');
  }
  final String value = raw.trim();
  if (value.isEmpty) {
    throw FormatException('$key wajib diisi.');
  }
  if (value.length > maxLength) {
    throw FormatException('$key melebihi batas $maxLength karakter.');
  }
  if (idLike && !RegExp(r'^[A-Za-z0-9._:\-]+$').hasMatch(value)) {
    throw FormatException('$key berisi karakter tidak valid.');
  }
  return value;
}

String? _optionalString(
  Map<String, Object?> body, {
  required String key,
  required int maxLength,
  bool idLike = false,
}) {
  final Object? raw = body[key];
  if (raw == null) {
    return null;
  }
  if (raw is! String) {
    throw FormatException('$key wajib berupa string.');
  }
  final String value = raw.trim();
  if (value.isEmpty) {
    return null;
  }
  if (value.length > maxLength) {
    throw FormatException('$key melebihi batas $maxLength karakter.');
  }
  if (idLike && !RegExp(r'^[A-Za-z0-9._:\-]+$').hasMatch(value)) {
    throw FormatException('$key berisi karakter tidak valid.');
  }
  return value;
}
