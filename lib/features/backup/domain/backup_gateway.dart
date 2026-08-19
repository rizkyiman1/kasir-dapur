import 'package:kasir_dapur/features/backup/domain/backup_models.dart';

abstract class BackupGateway {
  Future<RemoteBackupInfo> upload({
    required String businessId,
    required String clientUuid,
    required BackupSnapshot snapshot,
  });

  Future<List<RemoteBackupInfo>> list(String businessId);

  Future<RemoteBackupInfo> getById({
    required String businessId,
    required String backupId,
  });
}
