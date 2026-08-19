abstract final class ContactParty {
  static const String customer = 'customer';
  static const String supplier = 'supplier';
}

abstract final class ContactEvent {
  static const String created = 'created';
  static const String updated = 'updated';
  static const String note = 'note';
}

final class ContactHistoryEntry {
  const ContactHistoryEntry({
    required this.id,
    required this.businessId,
    required this.partyType,
    required this.partyId,
    required this.event,
    required this.summary,
    this.amount,
    this.refId,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String partyType;
  final String partyId;
  final String event;
  final String summary;
  final int? amount;
  final String? refId;
  final int createdAt;
}
