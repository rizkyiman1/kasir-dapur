import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/sync/domain/sync_job.dart';

final syncSnapshotProvider = FutureProvider<SyncSnapshot>((Ref ref) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(syncEngineProvider).snapshot(businessId);
});

final class SyncController {
  SyncController(this._ref);

  final Ref _ref;

  Future<SyncRunResult> run({bool retryFailed = false}) async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final SyncRunResult result = await _ref
        .read(syncEngineProvider)
        .run(businessId: businessId, retryFailed: retryFailed);
    _ref.invalidate(syncSnapshotProvider);
    return result;
  }
}

final syncControllerProvider = Provider<SyncController>((Ref ref) {
  return SyncController(ref);
});
