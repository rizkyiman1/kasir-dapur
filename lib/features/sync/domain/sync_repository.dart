import 'package:kasir_dapur/features/sync/domain/sync_job.dart';

abstract class SyncRepository {
  Future<SyncJob> enqueue({
    required String businessId,
    required String clientUuid,
    required String aggregate,
    required String operation,
    required String payload,
  });

  Future<List<SyncJob>> pending({required String businessId});

  Future<List<SyncJob>> failed({required String businessId});

  Future<int> countByStatus({
    required String businessId,
    required String status,
  });

  Future<void> markSyncing(String id);

  Future<void> markDone(String id);

  Future<void> markFailed({required String id, required String error});

  Future<int> retryFailed(String businessId);

  Future<void> markPendingForRetry(String id);

  Future<void> requeueStaleSyncing(String businessId);

  Future<List<SyncLog>> recentLogs({
    required String businessId,
    int limit = 20,
  });

  Future<SyncLog> writeLog({
    required String businessId,
    String? queueId,
    required String direction,
    required String status,
    String? message,
  });
}
