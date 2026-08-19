final class StoredBackup {
  const StoredBackup({
    required this.id,
    required this.businessId,
    required this.clientUuid,
    required this.createdAt,
    required this.snapshot,
    required this.counts,
  });

  final String id;
  final String businessId;
  final String clientUuid;
  final int createdAt;
  final Map<String, Object?> snapshot;
  final Map<String, int> counts;

  Map<String, Object?> toListJson() {
    return <String, Object?>{
      'id': id,
      'backup_id': id,
      'business_id': businessId,
      'created_at': createdAt,
      'counts': counts,
    };
  }

  Map<String, Object?> toDetailJson() {
    return <String, Object?>{...toListJson(), 'snapshot': snapshot};
  }
}
