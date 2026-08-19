import 'dart:convert';

import 'package:kasir_dapur/core/constants/app_constants.dart';
import 'package:kasir_dapur/core/errors/app_exception.dart';
import 'package:kasir_dapur/features/dashboard/domain/dashboard_period.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_gate.dart';
import 'package:kasir_dapur/features/subscription/domain/feature_key.dart';
import 'package:kasir_dapur/features/subscription/domain/subscription_service.dart';
import 'package:kasir_dapur/features/sync/data/sync_snapshot_loader.dart';
import 'package:kasir_dapur/features/sync/domain/cloud_sync_gateway.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';
import 'package:kasir_dapur/features/sync/domain/sync_repository.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:kasir_dapur/services/settings_repository.dart';

/// Menyalin antrian SQLite ke backend. Tidak mengganti database transaksi.
final class SyncEngine {
  SyncEngine({
    required SyncRepository store,
    required CloudSyncGateway gateway,
    required ConnectivityPort connectivity,
    required SyncSnapshotLoader loader,
    required SubscriptionService subscriptions,
    required SettingsRepository settings,
    required ClockService clock,
  }) : _store = store,
       _gateway = gateway,
       _connectivity = connectivity,
       _loader = loader,
       _subscriptions = subscriptions,
       _settings = settings,
       _clock = clock;

  final SyncRepository _store;
  final CloudSyncGateway _gateway;
  final ConnectivityPort _connectivity;
  final SyncSnapshotLoader _loader;
  final SubscriptionService _subscriptions;
  final SettingsRepository _settings;
  final ClockService _clock;

  bool _running = false;

  Future<SyncSnapshot> snapshot(String businessId) async {
    final bool online = await _connectivity.isOnline();
    final int pending = await _store.countByStatus(
      businessId: businessId,
      status: SyncJobStatus.pending,
    );
    final int failed = await _store.countByStatus(
      businessId: businessId,
      status: SyncJobStatus.failed,
    );
    final int done = await _store.countByStatus(
      businessId: businessId,
      status: SyncJobStatus.done,
    );
    final String? lastRaw = await _settings.read(
      '${AppConstants.settingsKeyLastSyncPrefix}$businessId',
    );
    return SyncSnapshot(
      status: _running
          ? SyncRunStatus.syncing
          : !online
          ? SyncRunStatus.offline
          : failed > 0
          ? SyncRunStatus.failed
          : pending > 0
          ? SyncRunStatus.idle
          : SyncRunStatus.success,
      pendingCount: pending,
      failedCount: failed,
      doneCount: done,
      lastSyncAt: lastRaw == null ? null : int.tryParse(lastRaw),
      online: online,
      logs: await _store.recentLogs(businessId: businessId),
      failedJobs: await _store.failed(businessId: businessId),
      pendingJobs: await _store.pending(businessId: businessId),
    );
  }

  Future<SyncRunResult> run({
    required String businessId,
    bool retryFailed = false,
  }) async {
    if (_running) {
      return const SyncRunResult(
        status: SyncRunStatus.syncing,
        pushed: 0,
        duplicates: 0,
        failed: 0,
        message: 'Sinkronisasi sedang berjalan.',
      );
    }
    _running = true;
    try {
      final FeatureGate gate = await _subscriptions.gate(businessId);
      if (!gate.canUse(FeatureKey.googleSheetsSync) &&
          !gate.canUse(FeatureKey.cloudSync)) {
        return const SyncRunResult(
          status: SyncRunStatus.skipped,
          pushed: 0,
          duplicates: 0,
          failed: 0,
          message: 'Sinkronisasi Google Sheets tersedia mulai paket Pro. SQLite tetap sumber data.',
        );
      }
      final bool online = await _connectivity.isOnline();
      if (!online) {
        await _store.writeLog(
          businessId: businessId,
          direction: 'push',
          status: 'offline',
          message: 'Perangkat offline. Transaksi lokal tetap berjalan.',
        );
        return const SyncRunResult(
          status: SyncRunStatus.offline,
          pushed: 0,
          duplicates: 0,
          failed: 0,
          message: 'Offline. Antrian menunggu koneksi.',
        );
      }
      if (retryFailed) {
        await _store.retryFailed(businessId);
      }
      await _promoteDueFailedJobs(businessId);
      await _store.requeueStaleSyncing(businessId);
      await _enqueueCoreSnapshots(businessId);
      await _enqueueDailyReport(businessId);
      final List<SyncJob> jobs = await _store.pending(businessId: businessId);
      if (jobs.isEmpty) {
        await _touchLastSync(businessId);
        return const SyncRunResult(
          status: SyncRunStatus.success,
          pushed: 0,
          duplicates: 0,
          failed: 0,
          message: 'Tidak ada antrian.',
        );
      }
      int pushed = 0;
      int duplicates = 0;
      int failed = 0;
      for (final SyncJob job in jobs) {
        if (job.attempts >= AppConstants.syncMaxAttempts) {
          // Job melebihi batas percobaan — catat di log agar bisa di-debug
          // dan lewati tanpa retry.
          await _store.writeLog(
            businessId: businessId,
            queueId: job.id,
            direction: 'push',
            status: 'abandoned',
            message:
                'Job ${job.aggregate}/${job.clientUuid} diabaikan setelah '
                '${job.attempts} percobaan (limit: ${AppConstants.syncMaxAttempts}).',
          );
          continue;
        }
        await _store.markSyncing(job.id);
        try {
          final Map<String, Object?> payload = await _loader.load(job);
          final CloudSyncBatchResult result = await _gateway.push(
            businessId: businessId,
            jobs: <CloudSyncJob>[
              CloudSyncJob(
                clientUuid: job.clientUuid,
                aggregate: job.aggregate,
                operation: job.operation,
                payload: payload,
              ),
            ],
          );
          if (result.failedClientUuids.contains(job.clientUuid)) {
            throw const ValidationException(
              'Backend menolak baris sinkronisasi.',
            );
          }
          await _store.markDone(job.id);
          pushed += result.accepted;
          duplicates += result.duplicates;
          await _store.writeLog(
            businessId: businessId,
            queueId: job.id,
            direction: 'push',
            status: result.duplicates > 0 ? 'duplicate' : 'ok',
            message: 'Salinan ${job.aggregate} ke Google Sheets lewat backend.',
          );
        } on Object catch (error) {
          failed += 1;
          await _store.markFailed(
            id: job.id,
            error: ErrorHandlerSafe.message(error),
          );
          await _store.writeLog(
            businessId: businessId,
            queueId: job.id,
            direction: 'push',
            status: 'failed',
            message: ErrorHandlerSafe.message(error),
          );
        }
      }
      await _touchLastSync(businessId);
      return SyncRunResult(
        status: failed > 0 ? SyncRunStatus.failed : SyncRunStatus.success,
        pushed: pushed,
        duplicates: duplicates,
        failed: failed,
        message: failed > 0
            ? '$failed antrian gagal. Data kasir tetap di SQLite.'
            : 'Sinkronisasi selesai. SQLite tetap database utama.',
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _enqueueDailyReport(String businessId) async {
    final DateTime now = _clock.now();
    final DateTime start = DashboardDateRange.startOfLocalDay(now);
    final DateTime end = start.add(const Duration(days: 1));
    final String dateKey =
        '${start.year.toString().padLeft(4, '0')}-'
        '${start.month.toString().padLeft(2, '0')}-'
        '${start.day.toString().padLeft(2, '0')}';
    await _store.enqueue(
      businessId: businessId,
      clientUuid: 'daily_report:$businessId:$dateKey',
      aggregate: SyncAggregate.dailyReport.storageValue,
      operation: 'upsert',
      payload: jsonEncode(<String, Object>{
        'id': dateKey,
        'date': dateKey,
        'start_ms': start.millisecondsSinceEpoch,
        'end_ms': end.millisecondsSinceEpoch,
      }),
    );
  }

  Future<void> _enqueueCoreSnapshots(String businessId) async {
    // Snapshot inti bisnis untuk backup/recovery cloud Sheets.
    await _store.enqueue(
      businessId: businessId,
      clientUuid: 'business:$businessId',
      aggregate: SyncAggregate.business.storageValue,
      operation: 'upsert',
      payload: jsonEncode(<String, Object>{'id': businessId}),
    );
    await _store.enqueue(
      businessId: businessId,
      clientUuid: 'settings:$businessId',
      aggregate: SyncAggregate.settings.storageValue,
      operation: 'upsert',
      payload: jsonEncode(<String, Object>{'id': businessId}),
    );
    await _store.enqueue(
      businessId: businessId,
      clientUuid: 'users:$businessId',
      aggregate: SyncAggregate.userAccount.storageValue,
      operation: 'upsert',
      payload: jsonEncode(<String, Object>{'id': businessId}),
    );
    await _store.enqueue(
      businessId: businessId,
      clientUuid: 'subscription:$businessId',
      aggregate: SyncAggregate.subscriptionMeta.storageValue,
      operation: 'upsert',
      payload: jsonEncode(<String, Object>{'id': businessId}),
    );
  }

  Future<void> _promoteDueFailedJobs(String businessId) async {
    final List<SyncJob> failedJobs = await _store.failed(
      businessId: businessId,
    );
    final int now = _clock.nowEpochMs();
    for (final SyncJob job in failedJobs) {
      if (_isBackoffElapsed(job: job, nowMs: now)) {
        await _store.markPendingForRetry(job.id);
        await _store.writeLog(
          businessId: businessId,
          queueId: job.id,
          direction: 'push',
          status: 'retry_scheduled',
          message:
              'Retry dijadwalkan untuk ${job.aggregate}/${job.clientUuid} '
              'setelah backoff percobaan ke-${job.attempts}.',
        );
      }
    }
  }

  bool _isBackoffElapsed({required SyncJob job, required int nowMs}) {
    final int attempt = job.attempts <= 0 ? 1 : job.attempts;
    final int seconds = _backoffSeconds(attempt);
    final int dueAt = job.updatedAt + (seconds * 1000);
    return nowMs >= dueAt;
  }

  int _backoffSeconds(int attempt) {
    // exponential backoff: 2, 4, 8, ... detik; cap 5 menit.
    final int raw = 1 << attempt;
    if (raw < 2) {
      return 2;
    }
    if (raw > 300) {
      return 300;
    }
    return raw;
  }

  Future<void> _touchLastSync(String businessId) {
    return _settings.write(
      '${AppConstants.settingsKeyLastSyncPrefix}$businessId',
      '${_clock.nowEpochMs()}',
    );
  }
}

/// Pesan aman tanpa mengimpor UI ErrorHandler di domain.
abstract final class ErrorHandlerSafe {
  static String message(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Sinkronisasi gagal. Data lokal tidak dihapus.';
  }
}
