import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kasir_dapur/app/providers.dart';
import 'package:kasir_dapur/features/backup/domain/backup_models.dart';

final backupUiSnapshotProvider = FutureProvider<BackupUiSnapshot>((
  Ref ref,
) async {
  final String businessId = await ref.watch(activeBusinessIdProvider.future);
  return ref.watch(backupServiceProvider).snapshot(businessId);
});

final class BackupController {
  BackupController(this._ref);

  final Ref _ref;

  Future<BackupRunResult> backupNow() async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final BackupRunResult result = await _ref
        .read(backupServiceProvider)
        .backupNow(businessId);
    _ref.invalidate(backupUiSnapshotProvider);
    return result;
  }

  Future<BackupRunResult> restore({
    required String backupId,
    required bool confirmed,
  }) async {
    final String businessId = await _ref.read(activeBusinessIdProvider.future);
    final BackupRunResult result = await _ref
        .read(backupServiceProvider)
        .restore(
          businessId: businessId,
          backupId: backupId,
          confirmed: confirmed,
        );
    _ref.invalidate(backupUiSnapshotProvider);
    return result;
  }
}

final backupControllerProvider = Provider<BackupController>((Ref ref) {
  return BackupController(ref);
});
