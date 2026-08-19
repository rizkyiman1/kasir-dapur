final class SyncJob {
  const SyncJob({
    required this.id,
    required this.businessId,
    required this.clientUuid,
    required this.aggregate,
    required this.operation,
    required this.payload,
    required this.status,
    required this.attempts,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String businessId;
  final String clientUuid;
  final String aggregate;
  final String operation;
  final String payload;
  final String status;
  final int attempts;
  final String? lastError;
  final int createdAt;
  final int updatedAt;

  bool get isPending => status == SyncJobStatus.pending;
  bool get isFailed => status == SyncJobStatus.failed;
  bool get isDone => status == SyncJobStatus.done;
}

abstract final class SyncJobStatus {
  static const String pending = 'pending';
  static const String syncing = 'syncing';
  static const String done = 'done';
  static const String failed = 'failed';
}

enum SyncAggregate {
  business,
  userAccount,
  product,
  inventory,
  transaction,
  stockMovement,
  expense,
  customer,
  supplier,
  cashSession,
  cashMovement,
  category,
  settings,
  subscriptionMeta,
  dailyReport;

  String get storageValue {
    return switch (this) {
      SyncAggregate.business => 'business',
      SyncAggregate.userAccount => 'user_account',
      SyncAggregate.product => 'product',
      SyncAggregate.inventory => 'inventory',
      SyncAggregate.transaction => 'transaction',
      SyncAggregate.stockMovement => 'stock_movement',
      SyncAggregate.expense => 'expense',
      SyncAggregate.customer => 'customer',
      SyncAggregate.supplier => 'supplier',
      SyncAggregate.cashSession => 'cash_session',
      SyncAggregate.cashMovement => 'cash_movement',
      SyncAggregate.category => 'category',
      SyncAggregate.settings => 'settings',
      SyncAggregate.subscriptionMeta => 'subscription_meta',
      SyncAggregate.dailyReport => 'daily_report',
    };
  }

  /// Tab Google Sheets (salinan, bukan database transaksi).
  String get sheetTab {
    return switch (this) {
      SyncAggregate.business => 'Businesses',
      SyncAggregate.userAccount => 'Users',
      SyncAggregate.product => 'Products',
      SyncAggregate.inventory => 'Inventory',
      SyncAggregate.transaction => 'Transactions',
      SyncAggregate.stockMovement => 'StockMovements',
      SyncAggregate.expense => 'Expenses',
      SyncAggregate.customer => 'Customers',
      SyncAggregate.supplier => 'Suppliers',
      SyncAggregate.cashSession => 'CashSessions',
      SyncAggregate.cashMovement => 'CashMovements',
      SyncAggregate.category => 'Categories',
      SyncAggregate.settings => 'Settings',
      SyncAggregate.subscriptionMeta => 'Subscriptions',
      SyncAggregate.dailyReport => 'DailyReports',
    };
  }

  static const String transactionItemsTab = 'TransactionItems';
}

final class SyncLog {
  const SyncLog({
    required this.id,
    required this.businessId,
    this.queueId,
    required this.direction,
    required this.status,
    this.message,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String? queueId;
  final String direction;
  final String status;
  final String? message;
  final int createdAt;
}

enum SyncRunStatus { idle, offline, skipped, syncing, success, failed }

final class SyncSnapshot {
  const SyncSnapshot({
    required this.status,
    required this.pendingCount,
    required this.failedCount,
    required this.doneCount,
    this.lastSyncAt,
    this.lastMessage,
    this.online = true,
    this.logs = const <SyncLog>[],
    this.failedJobs = const <SyncJob>[],
    this.pendingJobs = const <SyncJob>[],
  });

  final SyncRunStatus status;
  final int pendingCount;
  final int failedCount;
  final int doneCount;
  final int? lastSyncAt;
  final String? lastMessage;
  final bool online;
  final List<SyncLog> logs;
  final List<SyncJob> failedJobs;
  final List<SyncJob> pendingJobs;
}

final class SyncRunResult {
  const SyncRunResult({
    required this.status,
    required this.pushed,
    required this.duplicates,
    required this.failed,
    this.message,
  });

  final SyncRunStatus status;
  final int pushed;
  final int duplicates;
  final int failed;
  final String? message;
}

final class CloudSyncJob {
  const CloudSyncJob({
    required this.clientUuid,
    required this.aggregate,
    required this.operation,
    required this.payload,
  });

  final String clientUuid;
  final String aggregate;
  final String operation;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'client_uuid': clientUuid,
      'aggregate': aggregate,
      'operation': operation,
      'payload': payload,
    };
  }
}

final class CloudSyncBatchResult {
  const CloudSyncBatchResult({
    required this.accepted,
    required this.duplicates,
    this.failedClientUuids = const <String>[],
  });

  final int accepted;
  final int duplicates;
  final List<String> failedClientUuids;
}
