import 'package:kasir_dapur/database/database_constants.dart';
import 'package:kasir_dapur/database/row_codec.dart';
import 'package:kasir_dapur/features/contacts/domain/contact_history.dart';
import 'package:kasir_dapur/services/clock_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

Future<void> writeContactHistory(
  DatabaseExecutor executor, {
  required ClockService clock,
  required Uuid uuid,
  required String businessId,
  required String partyType,
  required String partyId,
  required String event,
  required String summary,
  int? amount,
  String? refId,
}) {
  return executor.insert(
    DatabaseConstants.tableContactHistory,
    <String, Object?>{
      'id': uuid.v4(),
      'business_id': businessId,
      'party_type': partyType,
      'party_id': partyId,
      'event': event,
      'summary': summary,
      'amount': amount,
      'ref_id': refId,
      'created_at': clock.nowEpochMs(),
    },
  );
}

Future<List<ContactHistoryEntry>> listContactHistory(
  DatabaseExecutor executor, {
  required String partyType,
  required String partyId,
}) async {
  final rows = await executor.query(
    DatabaseConstants.tableContactHistory,
    where: 'party_type = ? AND party_id = ?',
    whereArgs: <Object>[partyType, partyId],
    orderBy: 'created_at DESC',
  );
  return rows.map(_mapHistory).toList();
}

ContactHistoryEntry _mapHistory(Map<String, Object?> row) {
  return ContactHistoryEntry(
    id: readString(row['id'], field: 'id'),
    businessId: readString(row['business_id'], field: 'business_id'),
    partyType: readString(row['party_type'], field: 'party_type'),
    partyId: readString(row['party_id'], field: 'party_id'),
    event: readString(row['event'], field: 'event'),
    summary: readString(row['summary'], field: 'summary'),
    amount: readIntOrNull(row['amount']),
    refId: readStringOrNull(row['ref_id']),
    createdAt: readInt(row['created_at'], field: 'created_at'),
  );
}

String? blankToNull(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
