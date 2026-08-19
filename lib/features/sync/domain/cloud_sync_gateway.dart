import 'package:kasir_dapur/features/sync/domain/sync_job.dart';

/// Gateway ke backend Kasir Dapur. Bukan ke Google Sheets langsung.
abstract class CloudSyncGateway {
  Future<CloudSyncBatchResult> push({
    required String businessId,
    required List<CloudSyncJob> jobs,
  });
}

abstract class ConnectivityPort {
  Future<bool> isOnline();
}
