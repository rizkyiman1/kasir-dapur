import 'dart:convert';

import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/core/logging/app_logger.dart';
import 'package:kasir_dapur/core/permissions/app_permission.dart';
import 'package:kasir_dapur/core/permissions/permission_guard.dart';
import 'package:kasir_dapur/features/backup/data/backup_log_repository.dart';
import 'package:kasir_dapur/features/backup/data/backup_restorer.dart';
import 'package:kasir_dapur/features/backup/data/backup_snapshot_builder.dart';
import 'package:kasir_dapur/features/backup/domain/backup_gateway.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';
import 'package:kasir_dapur/features/sync/domain/cloud_sync_gateway.dart';
import 'package:kasir_dapur/services/settings_repository.dart';
import 'package:uuid/uuid.dart';

/// Cadangan cloud. Tidak mengganti SQLite sebagai database transaksi.
final class BackupService {
  BackupService({
    required BackupSnapshotBuilder builder,
    required BackupRestorer restorer,
    required BackupGateway gateway,
    required SqliteBackupLogRepository logs,
    required SubscriptionService subscriptions,
    required ConnectivityPort connectivity,
    required SettingsRepository settings,
    required PermissionGuard guard,
    required AccessContext Function() access,
    Uuid? uuid,
  }) : _builder = builder,
       _restorer = restorer,
       _gateway = gateway,
       _logs = logs,
       _subscriptions = subscriptions,
       _connectivity = connectivity,
       _settings = settings,
       _guard = guard,
       _access = access,
       _uuid = uuid ?? const Uuid();

  final BackupSnapshotBuilder _builder;
  final BackupRestorer _restorer;
  final BackupGateway _gateway;
  final SqliteBackupLogRepository _logs;
  final SubscriptionService _subscriptions;
  final ConnectivityPort _connectivity;
  final SettingsRepository _settings;
  final PermissionGuard _guard;
  final AccessContext Function() _access;
  final Uuid _uuid;

  bool _busy = false;
  String _phase = BackupStatus.idle;
  static const int _maxLocalPreRestoreSnapshotChars = 2 * 1024 * 1024;

  Future<BackupUiSnapshot> snapshot(String businessId) async {
    _require();
    final bool online = await _connectivity.isOnline();
    List<RemoteBackupInfo> remote = const <RemoteBackupInfo>[];
    if (online) {
      try {
        remote = await _gateway.list(businessId);
      } on Object catch (error, stack) {
        AppLogger.instance.error(
          'backup_service: gagal memuat daftar backup remote',
          error: error,
          stackTrace: stack,
        );
        remote = const <RemoteBackupInfo>[];
      }
    }
    final String? lastAt = await _settings.read(
      '${AppConstants.settingsKeyLastBackupAtPrefix}$businessId',
    );
    final String? lastId = await _settings.read(
      '${AppConstants.settingsKeyLastBackupIdPrefix}$businessId',
    );
    final String? lastStatus = await _settings.read(
      '${AppConstants.settingsKeyLastBackupStatusPrefix}$businessId',
    );
    final List<BackupLog> logs = await _logs.recent(businessId: businessId);
    return BackupUiSnapshot(
      status: _busy
          ? _phase
          : lastStatus ??
                (logs.isEmpty ? BackupStatus.idle : logs.first.status),
      lastBackupAt: lastAt == null ? null : int.tryParse(lastAt),
      lastBackupId: lastId,
      lastMessage: logs.isEmpty ? null : logs.first.message,
      online: online,
      remote: remote,
      logs: logs,
    );
  }

  Future<BackupRunResult> backupNow(String businessId) async {
    _require();
    if (_busy) {
      return const BackupRunResult(
        status: BackupStatus.backingUp,
        message: 'Cadangan sedang berjalan.',
      );
    }
    final gate = await _subscriptions.gate(businessId);
    if (!gate.canUse(FeatureKey.cloudBackup) &&
        !gate.canUse(FeatureKey.advancedBackup)) {
      return const BackupRunResult(
        status: BackupStatus.skipped,
        message: 'Cadangan cloud tersedia mulai paket Pro. SQLite tetap aman.',
      );
    }
    _busy = true;
    _phase = BackupStatus.backingUp;
    try {
      final bool online = await _connectivity.isOnline();
      if (!online) {
        await _logs.write(
          businessId: businessId,
          direction: BackupDirection.upload,
          status: BackupStatus.failed,
          message: 'Offline. Transaksi kasir tetap berjalan di SQLite.',
        );
        await _touchStatus(businessId, BackupStatus.failed);
        return const BackupRunResult(
          status: BackupStatus.failed,
          message: 'Offline. Kasir tetap dapat digunakan.',
        );
      }
      final BackupSnapshot payload = await _builder.build(businessId);
      final RemoteBackupInfo stored = await _gateway.upload(
        businessId: businessId,
        clientUuid: _uuid.v4(),
        snapshot: payload,
      );
      await _logs.write(
        businessId: businessId,
        remoteId: stored.id,
        direction: BackupDirection.upload,
        status: BackupStatus.success,
        message: 'Cadangan tersimpan. SQLite tetap database transaksi.',
        tablesJson: jsonEncode(payload.counts),
      );
      await _settings.write(
        '${AppConstants.settingsKeyLastBackupAtPrefix}$businessId',
        '${payload.createdAt}',
      );
      await _settings.write(
        '${AppConstants.settingsKeyLastBackupIdPrefix}$businessId',
        stored.id,
      );
      await _touchStatus(businessId, BackupStatus.success);
      return BackupRunResult(
        status: BackupStatus.success,
        backupId: stored.id,
        message: 'Cadangan selesai. Kasir tidak terganggu.',
        counts: payload.counts,
      );
    } on Object catch (error, stack) {
      AppLogger.instance.error(
        'backup_service: backupNow gagal',
        error: error,
        stackTrace: stack,
      );
      await _logs.write(
        businessId: businessId,
        direction: BackupDirection.upload,
        status: BackupStatus.failed,
        message: _safe(error),
      );
      await _touchStatus(businessId, BackupStatus.failed);
      return BackupRunResult(
        status: BackupStatus.failed,
        message: _safe(error),
      );
    } finally {
      _busy = false;
    }
  }

  Future<BackupRunResult> restore({
    required String businessId,
    required String backupId,
    required bool confirmed,
  }) async {
    _require();
    if (!confirmed) {
      throw const ValidationException(
        'Pemulihan cadangan membutuhkan konfirmasi.',
      );
    }
    if (_busy) {
      return const BackupRunResult(
        status: BackupStatus.restoring,
        message: 'Cadangan sedang diproses.',
      );
    }
    final gate = await _subscriptions.gate(businessId);
    if (!gate.canUse(FeatureKey.cloudBackup) &&
        !gate.canUse(FeatureKey.advancedBackup)) {
      return const BackupRunResult(
        status: BackupStatus.skipped,
        message: 'Pemulihan cadangan tersedia mulai paket Pro.',
      );
    }
    _busy = true;
    _phase = BackupStatus.restoring;
    try {
      final RemoteBackupInfo remote = await _gateway.getById(
        businessId: businessId,
        backupId: backupId,
      );
      _phase = 'validating';
      final BackupSnapshot? payload = remote.snapshot;
      if (payload == null) {
        throw const NotFoundException('Isi cadangan kosong.');
      }
      await _snapshotBeforeRestoreIfNeeded(businessId);
      _phase = 'restoring';
      await _restorer.restore(payload, businessId: businessId);
      _phase = 'committed';
      final int restoredAt = DateTime.now().millisecondsSinceEpoch;
      final int restoredCount = payload.counts.values.fold<int>(
        0,
        (int sum, int value) => sum + value,
      );
      await _logs.write(
        businessId: businessId,
        remoteId: backupId,
        direction: BackupDirection.restore,
        status: BackupStatus.success,
        message: 'Pemulihan selesai. Restored $restoredCount baris.',
        tablesJson: jsonEncode(payload.counts),
      );
      await _settings.write(
        '${AppConstants.settingsKeyLastRestoreAtPrefix}$businessId',
        '$restoredAt',
      );
      await _settings.write(
        '${AppConstants.settingsKeyLastRestoreStatusPrefix}$businessId',
        BackupStatus.success,
      );
      await _settings.write(
        '${AppConstants.settingsKeyLastRestoreCountPrefix}$businessId',
        '$restoredCount',
      );
      return BackupRunResult(
        status: BackupStatus.success,
        backupId: backupId,
        message:
            'Data cadangan dipulihkan ke SQLite. Kasir tetap dapat digunakan.',
        counts: payload.counts,
      );
    } on Object catch (error, stack) {
      AppLogger.instance.error(
        'backup_service: restore gagal',
        error: error,
        stackTrace: stack,
      );
      await _logs.write(
        businessId: businessId,
        remoteId: backupId,
        direction: BackupDirection.restore,
        status: BackupStatus.failed,
        message: _safe(error),
      );
      await _settings.write(
        '${AppConstants.settingsKeyLastRestoreStatusPrefix}$businessId',
        BackupStatus.failed,
      );
      return BackupRunResult(
        status: BackupStatus.failed,
        message: _safe(error),
      );
    } finally {
      _busy = false;
      _phase = BackupStatus.idle;
    }
  }

  void _require() {
    _guard.require(_access(), AppPermission.manageSettings);
  }

  Future<void> _touchStatus(String businessId, String status) {
    return _settings.write(
      '${AppConstants.settingsKeyLastBackupStatusPrefix}$businessId',
      status,
    );
  }

  String _safe(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Cadangan gagal. Kasir tetap dapat digunakan.';
  }

  Future<void> _snapshotBeforeRestoreIfNeeded(String businessId) async {
    try {
      final BackupSnapshot local = await _builder.build(businessId);
      final int currentRows = local.counts.values.fold<int>(
        0,
        (int sum, int value) => sum + value,
      );
      if (currentRows == 0) {
        return;
      }
      final String encoded = jsonEncode(local.toJson());
      if (encoded.length <= _maxLocalPreRestoreSnapshotChars) {
        await _settings.write(
          '${AppConstants.settingsKeyPreRestoreSnapshotPrefix}$businessId',
          encoded,
        );
      }
      await _logs.write(
        businessId: businessId,
        direction: BackupDirection.restore,
        status: 'pre_restore_backup',
        message:
            'Snapshot lokal sebelum restore disimpan ($currentRows baris).',
        tablesJson: jsonEncode(local.counts),
      );
    } on Object catch (error, stack) {
      AppLogger.instance.error(
        'backup_service: gagal membuat snapshot lokal sebelum restore',
        error: error,
        stackTrace: stack,
      );
    }
  }
}
