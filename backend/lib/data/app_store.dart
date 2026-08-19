import 'package:kasir_dapur_backend/backup/stored_backup.dart';
import 'package:kasir_dapur_backend/domain/records.dart';
import 'package:kasir_dapur_backend/sync/sheets_mirror.dart';
import 'package:uuid/uuid.dart';

final class RegisteredDevice {
  RegisteredDevice({
    required this.id,
    required this.businessId,
    required this.userId,
    required this.deviceName,
    required this.status,
    required this.createdAt,
    required this.lastSeenAt,
  });

  final String id;
  final String businessId;
  final String userId;
  final String deviceName;
  String status;
  final int createdAt;
  int lastSeenAt;
}

final class BranchRecord {
  BranchRecord({
    required this.id,
    required this.businessId,
    required this.name,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  String name;
  String status;
  final int createdAt;
}

final class Clock {
  const Clock();

  int nowEpochMs() => DateTime.now().millisecondsSinceEpoch;
}

final class AdjustableClock extends Clock {
  AdjustableClock([int? initial]) : now = initial ?? 1_000_000;

  int now;

  @override
  int nowEpochMs() => now;
}

final class AppStore {
  AppStore({Clock? clock, Uuid? uuid})
    : clock = clock ?? const Clock(),
      _uuid = uuid ?? const Uuid();

  final Clock clock;
  final Uuid _uuid;

  final Map<String, PaymentRecord> paymentsByOrder = <String, PaymentRecord>{};
  final Map<String, PaymentRecord> paymentsByClientUuid =
      <String, PaymentRecord>{};
  final Map<String, SubscriptionRecord> entitledByBusiness =
      <String, SubscriptionRecord>{};
  final Map<String, List<EntitlementRecord>> entitlementsByBusiness =
      <String, List<EntitlementRecord>>{};
  final Set<String> webhookFingerprints = <String>{};
  final List<AuditEvent> audit = <AuditEvent>[];
  final List<Map<String, Object?>> syncJobs = <Map<String, Object?>>[];
  final List<StoredBackup> backups = <StoredBackup>[];
  final MemorySheetsMirror sheets = MemorySheetsMirror();
  final List<RegisteredDevice> devices = <RegisteredDevice>[];
  final List<BranchRecord> branches = <BranchRecord>[];

  String nextId() => _uuid.v4();

  StoredBackup? backupByClientUuid(String clientUuid) {
    for (final StoredBackup row in backups) {
      if (row.clientUuid == clientUuid) {
        return row;
      }
    }
    return null;
  }

  StoredBackup? backupById(String id) {
    for (final StoredBackup row in backups) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }

  List<StoredBackup> backupsFor(String businessId) {
    return backups
        .where((StoredBackup row) => row.businessId == businessId)
        .toList()
      ..sort(
        (StoredBackup a, StoredBackup b) => b.createdAt.compareTo(a.createdAt),
      );
  }

  PaymentRecord? paymentByOrder(String orderId) => paymentsByOrder[orderId];

  PaymentRecord? paymentByClientUuid(String clientUuid) =>
      paymentsByClientUuid[clientUuid];

  void savePayment(PaymentRecord payment) {
    paymentsByOrder[payment.orderId] = payment;
    paymentsByClientUuid[payment.clientUuid] = payment;
  }

  List<PaymentRecord> paymentsFor(String businessId) {
    return paymentsByOrder.values
        .where((PaymentRecord row) => row.businessId == businessId)
        .toList()
      ..sort(
        (PaymentRecord a, PaymentRecord b) =>
            b.createdAt.compareTo(a.createdAt),
      );
  }

  bool seenWebhook(String fingerprint) =>
      webhookFingerprints.contains(fingerprint);

  void rememberWebhook(String fingerprint) {
    webhookFingerprints.add(fingerprint);
  }

  bool hasSyncJob({required String businessId, required String clientUuid}) {
    return syncJobs.any(
      (Map<String, Object?> job) =>
          job['business_id'] == businessId && job['client_uuid'] == clientUuid,
    );
  }

  void rememberSyncJob({
    required String businessId,
    required String clientUuid,
    required String aggregate,
  }) {
    syncJobs.add(<String, Object?>{
      'id': nextId(),
      'client_uuid': clientUuid,
      'business_id': businessId,
      'aggregate': aggregate,
      'received_at': clock.nowEpochMs(),
    });
  }

  void writeAudit({
    required String action,
    required String entity,
    String? businessId,
    String? orderId,
    required String detail,
  }) {
    audit.add(
      AuditEvent(
        id: nextId(),
        at: clock.nowEpochMs(),
        action: action,
        entity: entity,
        businessId: businessId,
        orderId: orderId,
        detail: detail,
      ),
    );
  }

  List<RegisteredDevice> devicesFor(String businessId) {
    return devices
        .where((RegisteredDevice row) => row.businessId == businessId)
        .toList()
      ..sort(
        (RegisteredDevice a, RegisteredDevice b) =>
            b.createdAt.compareTo(a.createdAt),
      );
  }

  RegisteredDevice? findDevice({
    required String businessId,
    required String deviceId,
  }) {
    for (final RegisteredDevice row in devices) {
      if (row.id == deviceId && row.businessId == businessId) {
        return row;
      }
    }
    return null;
  }

  RegisteredDevice? findDeviceByName({
    required String businessId,
    required String deviceName,
  }) {
    for (final RegisteredDevice row in devices) {
      if (row.businessId == businessId && row.deviceName == deviceName) {
        return row;
      }
    }
    return null;
  }

  List<BranchRecord> branchesFor(String businessId) {
    return branches
        .where((BranchRecord row) => row.businessId == businessId)
        .toList()
      ..sort((BranchRecord a, BranchRecord b) => a.name.compareTo(b.name));
  }

  BranchRecord? findBranch({
    required String businessId,
    required String branchId,
  }) {
    for (final BranchRecord row in branches) {
      if (row.id == branchId && row.businessId == businessId) {
        return row;
      }
    }
    return null;
  }
}
