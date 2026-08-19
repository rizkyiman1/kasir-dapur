abstract final class BackupTables {
  static const String businesses = 'businesses';
  static const String businessSettings = 'business_settings';
  static const String localUsers = 'local_users';
  static const String products = 'products';
  static const String categories = 'categories';
  static const String suppliers = 'suppliers';
  static const String transactions = 'transactions';
  static const String transactionItems = 'transaction_items';
  static const String payments = 'payments';
  static const String stock = 'stock';
  static const String stockMovements = 'stock_movements';
  static const String cashSessions = 'cash_sessions';
  static const String cashMovements = 'cash_movements';
  static const String expenses = 'expenses';
  static const String expenseCategories = 'expense_categories';
  static const String customers = 'customers';
  static const String subscriptions = 'subscriptions';
  static const String entitlements = 'entitlements';
  static const String settings = 'settings';

  static const List<String> all = <String>[
    businesses,
    businessSettings,
    localUsers,
    products,
    categories,
    suppliers,
    transactions,
    transactionItems,
    payments,
    stock,
    stockMovements,
    cashSessions,
    cashMovements,
    expenses,
    expenseCategories,
    customers,
    subscriptions,
    entitlements,
    settings,
  ];
}

abstract final class BackupStatus {
  static const String idle = 'idle';
  static const String backingUp = 'backing_up';
  static const String restoring = 'restoring';
  static const String success = 'success';
  static const String failed = 'failed';
  static const String skipped = 'skipped';
}

abstract final class BackupDirection {
  static const String upload = 'upload';
  static const String restore = 'restore';
}

final class BackupLog {
  const BackupLog({
    required this.id,
    required this.businessId,
    this.remoteId,
    required this.direction,
    required this.status,
    this.message,
    this.tablesJson,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String? remoteId;
  final String direction;
  final String status;
  final String? message;
  final String? tablesJson;
  final int createdAt;
}

final class BackupSnapshot {
  const BackupSnapshot({
    required this.businessId,
    required this.createdAt,
    required this.schemaVersion,
    this.checksum,
    required this.tables,
  });

  final String businessId;
  final int createdAt;
  final int schemaVersion;
  final String? checksum;
  final Map<String, List<Map<String, Object?>>> tables;

  Map<String, int> get counts {
    return <String, int>{
      for (final String name in BackupTables.all)
        name: tables[name]?.length ?? 0,
    };
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'business_id': businessId,
      'created_at': createdAt,
      'schema_version': schemaVersion,
      if (checksum != null) 'checksum': checksum,
      'tables': <String, Object?>{
        for (final MapEntry<String, List<Map<String, Object?>>> entry
            in tables.entries)
          entry.key: entry.value,
      },
    };
  }

  factory BackupSnapshot.fromJson(Map<String, Object?> json) {
    final Object? rawTables = json['tables'];
    final Map<String, List<Map<String, Object?>>> tables =
        <String, List<Map<String, Object?>>>{};
    if (rawTables is Map) {
      for (final MapEntry<Object?, Object?> entry in rawTables.entries) {
        final Object? rows = entry.value;
        if (rows is! List) {
          continue;
        }
        tables[entry.key.toString()] = rows.map(_asRow).toList();
      }
    }
    return BackupSnapshot(
      businessId: json['business_id'] as String? ?? '',
      createdAt: json['created_at'] is int ? json['created_at']! as int : 0,
      schemaVersion: json['schema_version'] is int
          ? json['schema_version']! as int
          : 0,
      checksum: json['checksum'] as String?,
      tables: tables,
    );
  }

  static Map<String, Object?> _asRow(Object? value) {
    if (value is Map) {
      return value.map(
        (Object? key, Object? val) =>
            MapEntry<String, Object?>(key.toString(), val),
      );
    }
    return <String, Object?>{};
  }
}

final class RemoteBackupInfo {
  const RemoteBackupInfo({
    required this.id,
    required this.businessId,
    required this.createdAt,
    this.counts = const <String, int>{},
    this.snapshot,
  });

  final String id;
  final String businessId;
  final int createdAt;
  final Map<String, int> counts;
  final BackupSnapshot? snapshot;
}

final class BackupUiSnapshot {
  const BackupUiSnapshot({
    required this.status,
    this.lastBackupAt,
    this.lastBackupId,
    this.lastMessage,
    this.online = true,
    this.remote = const <RemoteBackupInfo>[],
    this.logs = const <BackupLog>[],
  });

  final String status;
  final int? lastBackupAt;
  final String? lastBackupId;
  final String? lastMessage;
  final bool online;
  final List<RemoteBackupInfo> remote;
  final List<BackupLog> logs;
}

final class BackupRunResult {
  const BackupRunResult({
    required this.status,
    this.backupId,
    this.message,
    this.counts = const <String, int>{},
  });

  final String status;
  final String? backupId;
  final String? message;
  final Map<String, int> counts;

  bool get isSuccess => status == BackupStatus.success;
}
